//
//  APIController.swift
//  hack
//
//  Created by Burton Lee on 4/12/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation

open class APIController {
    
    open class APIParameters {
        
        public init(urlString: String,
             successNotification: Notification.Name? = nil,
             failureNotification: Notification.Name? = nil,
             successClosure: (([AnyObject]) -> Void)? = nil,
             failureClosure: ((Error?) -> Void)? = nil,
             type: APIObject.Type? = nil,
             jsonKey: String? = nil,
             httpVerb: httpVerb? = nil,
             inputObject: APIObject? = nil,
             cachePolicy: NSURLRequest.CachePolicy? = nil,
             timeoutInterval: Double? = nil,
             queueOnFailure: Bool = false) {
            
            self.urlString = urlString
            self.successNotification = successNotification
            self.failureNotification = failureNotification
            self.successClosure = successClosure
            self.failureClosure = failureClosure
            self.type = type
            self.jsonKey = jsonKey
            self.httpVerb = httpVerb
            self.inputObject = inputObject
            self.cachePolicy = cachePolicy
            self.timeoutInterval = timeoutInterval
            self.queueOnFailure = queueOnFailure
        }
        
        let urlString: String
        let successNotification: Notification.Name?
        let failureNotification: Notification.Name?
        let successClosure: (([AnyObject]) -> Void)?
        let failureClosure: ((Error?) -> Void)?
        let type: APIObject.Type?
        let jsonKey: String?
        let httpVerb: httpVerb?
        let inputObject: APIObject?
        let cachePolicy: NSURLRequest.CachePolicy?
        let timeoutInterval: Double?
        let queueOnFailure: Bool
    }
    
    public var defaultCachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy
    public var defaultTimeoutInterval = 60.0
    
    public let host: String
    public var reachability: Reachability?
    
    public var commandQueue = [URLSessionTask]()
    public let urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral)
    
    public init(host: String) {
        
        self.host = host;
        self.reachability = Reachability(hostname: self.host)
        
        if (self.reachability != nil) {
            self.reachability!.whenReachable = self.processQueue()
        }
    }
    
    deinit {
        self.reachability = nil
        self.urlSession.invalidateAndCancel()
    }
    
    public struct dictionaryKeys {
        static let data = "data"
        static let error = "error"
        static let json = "json"
        static let rawData = "rawdata"
        static let reason = "reason"
    }
    
    public enum httpVerb: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    public enum APIControllerErrors: Int, Error {
        case BadJSONKey = 101
        case UnreachableServer
        static let domain = "APIController"
    }
        
    public func serverInteractionBy(parameters: APIParameters) {
        self.serverInteractionBy(parameters: parameters, parseFunction: self.defaultParseFunction())
    }
    
    public func serverInteractionBy(parameters: APIParameters, parseFunction: @escaping ((Data, APIParameters)
        throws -> Void)) {
        
        if let url = URL(string:parameters.urlString) {
            var request = URLRequest(url: url, cachePolicy: parameters.cachePolicy ?? self.defaultCachePolicy,
                                timeoutInterval: parameters.timeoutInterval ?? self.defaultTimeoutInterval)
            request.httpMethod = parameters.httpVerb?.rawValue ?? httpVerb.GET.rawValue
            
            let completionBlock: (Data?, URLResponse?, Error?) -> Void = { (data, response, error) in
                
                DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                    
                    if (error != nil || data == nil) {
                        self.failWith(notification: parameters.failureNotification, closure:parameters.failureClosure, error: error)
                        
                    } else {
                        do {
                            try parseFunction(data!, parameters)
                            
                        } catch APIControllerErrors.BadJSONKey {
                            self.failWith(notification: parameters.failureNotification, closure: parameters.failureClosure, error: NSError(domain: APIControllerErrors.domain, code: APIControllerErrors.BadJSONKey.rawValue, userInfo: [APIController.dictionaryKeys.reason : "Bad JSON path key: \(parameters.jsonKey)", APIController.dictionaryKeys.json : parameters.jsonKey!]))
                            
                        } catch {
                            self.failWith(notification: parameters.failureNotification, closure: parameters.failureClosure, error:nil)
                        }
                    }
                }
            }
            
            let task = self.urlSession.dataTask(with: request, completionHandler: completionBlock)
            
            if !(self.reachability != nil && self.reachability!.isReachable) {
                if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
                    completionBlock(cachedResponse.data, cachedResponse.response, nil)
               
                } else {
                    self.failWith(notification: parameters.failureNotification, closure: parameters.failureClosure, error: NSError(domain: APIControllerErrors.domain, code: APIControllerErrors.UnreachableServer.rawValue, userInfo: [APIController.dictionaryKeys.reason : "Unreachable Host: \(self.host)"]))
                }
                
                if parameters.queueOnFailure {
                    self.commandQueue.append(task)
                }
                
            } else {
                    task.resume()
            }
            
        } else {
            assertionFailure("BAD URL: \(parameters.urlString)")
        }
    }
    
    public func defaultParseFunction() -> (Data, APIParameters) throws -> Void {
        return { (data, parameters) in
            
            let json = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions())
            var objectArray = [AnyObject]()
            var interior = json
            
            if parameters.jsonKey != nil {
                let keysArray = parameters.jsonKey!.components(separatedBy:".")
                
                for key in keysArray {
                    if let d = (interior as! NSDictionary)[key] {
                        interior = d;
                    } else {
                        throw APIControllerErrors.BadJSONKey
                    }
                }
            }
            
            if interior is NSDictionary {
                interior = [interior]
            }
            
            let rawArray = interior as! [NSDictionary]
            
            if parameters.type != nil {
                for dictionary: NSDictionary in rawArray {
                    if let object = parameters.type!.init(dictionary: dictionary) {
                        objectArray.append(object)
                    }
                }
            } else {
                objectArray = rawArray
            }
            
            self.succeedWith(notification: parameters.successNotification, closure: parameters.successClosure, data: objectArray)
        }
    }
    
    private func failWith(notification: Notification.Name?, closure: ((Error?) -> Void)?, error: Error?) {
        
        if (notification == nil && closure == nil) {
            return;
        }
        
        DispatchQueue.main.async {
            
            if let note = notification {
                var userInfo : [String : AnyObject]?
                if (error != nil) {
                    userInfo = [APIController.dictionaryKeys.error : error! as AnyObject]
                }
                
                NotificationCenter.default.post(name: note, object: self, userInfo: userInfo)
            }
            
            if let block = closure {
                block(error)
            }
        }
    }
    
    private func succeedWith(notification: Notification.Name?, closure: (([AnyObject]) -> Void)?, data: [AnyObject]) {
        
        assert(notification != nil || closure != nil)
        
        DispatchQueue.main.async {
            if let note = notification {
                NotificationCenter.default.post(name: note, object: self, userInfo: [APIController.dictionaryKeys.data : data])
            }
            
            if let block = closure {
                block(data)
            }
        }
    }
    
    private func processQueue() -> (Reachability) -> Void  {
        
        return { (reachability) in
            if self.commandQueue.count > 0 {
                var newQueue = [URLSessionTask]()
                
                for task in self.commandQueue {
                    if (reachability.isReachable) {
                        task.resume()
                    } else {
                        newQueue.append(task)
                    }
                }
                
                self.commandQueue = newQueue;
            }
        }
    }
    
}

extension Notification {
    
    public func objectData() -> [AnyObject] {
        
        if (self.userInfo == nil) {
            return [AnyObject]()
        }
        
        return self.userInfo![APIController.dictionaryKeys.data] as! Array
    }
    
    public func errorData() -> Error? {
        
        return self.userInfo?[APIController.dictionaryKeys.error] as? Error
    }
}

