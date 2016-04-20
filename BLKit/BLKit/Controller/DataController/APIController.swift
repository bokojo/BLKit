//
//  APIController.swift
//  hack
//
//  Created by Burton Lee on 4/12/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation

class APIController {
    
    var defaultCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
    var defaultTimeoutInterval = 60.0
    let host: String;
    var reachability: Reachability?;
    
    init(host: String) {
        
        self.host = host;
        self.reachability = try? Reachability(hostname: self.host)
    }
    
    struct dictionaryKeys {
        static let data = "data"
        static let error = "error"
        static let json = "json"
        static let rawData = "rawdata"
        static let reason = "reason"
    }
    
    enum HTTPVerb: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    enum APIControllerErrors: Int, ErrorType {
        case BadJSONKey = 101
        case UnreachableServer
        static let domain = "APIController"
    }
    
    class apiParameters {
        
        init(urlString: String, successNotification: String? = nil, failureNotification: String? = nil, successClosure: (([AnyObject]) -> Void)? = nil, failureClosure: ((NSError?) -> Void)? = nil, type: APIObject.Type? = nil, jsonKey: String? = nil, httpVerb: HTTPVerb? = nil, inputObject: APIObject? = nil, cachePolicy: NSURLRequestCachePolicy? = nil, timeoutInterval: Double? = nil) {
            
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
        }
        
        let urlString: String
        let successNotification: String?
        let failureNotification: String?
        let successClosure: (([AnyObject]) -> Void)?
        let failureClosure: ((NSError?) -> Void)?
        let type: APIObject.Type?
        let jsonKey: String?
        let httpVerb: HTTPVerb?
        let inputObject: APIObject?
        let cachePolicy: NSURLRequestCachePolicy?
        let timeoutInterval: Double?
    }
    
    func serverInterationBy(parameters: apiParameters) {
        self.serverInteractionBy(parameters, parseFunction: self.defaultParseFunction())
    }
    
    func serverInteractionBy(parameters: apiParameters, parseFunction: ((data: NSData, parameters: apiParameters) -> Void)) {
        
        if let url = NSURL(string:parameters.urlString) {
            
            let request = NSMutableURLRequest(URL: url, cachePolicy: parameters.cachePolicy ?? self.defaultCachePolicy, timeoutInterval: parameters.timeoutInterval ?? self.defaultTimeoutInterval)
            
            request.HTTPMethod = parameters.httpVerb?.rawValue ?? HTTPVerb.GET.rawValue
            
            let completionBlock: (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void = { (data, response, error) in
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
                    
                    if (error != nil || data == nil) {
                        self.failWith(parameters.failureNotification, closure:parameters.failureClosure, error: error)
                        
                    } else {
                        parseFunction(data: data!, parameters: parameters)
                    }
                }
            }
            
            let task = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration()).dataTaskWithRequest(request, completionHandler: completionBlock)
            
           
            if !(self.reachability != nil && self.reachability!.isReachable()) {
                
                if let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request) {
                    completionBlock(data: cachedResponse.data, response: cachedResponse.response, error: nil)
               
                } else {
                    self.failWith(parameters.failureNotification, closure: parameters.failureClosure, error: NSError(domain: APIControllerErrors.domain, code: APIControllerErrors.UnreachableServer.rawValue, userInfo: [APIController.dictionaryKeys.reason : "Unreachable Host: \(self.host)"]))
                }
                
            } else {
                    task.resume()
            }
                
            
        } else {
            assertionFailure("BAD URL: \(parameters.urlString)")
        }
    }
    
    func defaultParseFunction() -> (data: NSData, parameters: apiParameters) -> Void {
        return { (data, parameters) in
            
            if let json = try? NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions()) {
                
                do {
                    let objectArray = try self.processJSON(json, jsonKey: parameters.jsonKey, type: parameters.type)
                    self.succeedWith(parameters.successNotification, closure: parameters.successClosure, data: objectArray)
                    
                } catch APIControllerErrors.BadJSONKey {
                    self.failWith(parameters.failureNotification, closure: parameters.failureClosure, error: NSError(domain: APIControllerErrors.domain, code: APIControllerErrors.BadJSONKey.rawValue, userInfo: [APIController.dictionaryKeys.reason : "Bad JSON path key: \(parameters.jsonKey)", APIController.dictionaryKeys.json : json]))
                    
                } catch {
                    self.failWith(parameters.failureNotification, closure: parameters.failureClosure, error:nil)
                }
                
            } else {
                self.failWith(parameters.failureNotification, closure: parameters.failureClosure, error: nil)
            }
        }
    }
    
    private func processJSON(json: AnyObject, jsonKey: String?, type: APIObject.Type?) throws -> [AnyObject] {
        
        var objectArray = [AnyObject]()
        var interior = json;
        
        if jsonKey != nil {
            let keysArray = jsonKey!.componentsSeparatedByString(".")
            
            for key in keysArray {
                if let d = interior[key] {
                    interior = d!;
                    
                } else {
                    throw APIControllerErrors.BadJSONKey
                }
            }
        }
        
        if interior is NSDictionary {
            interior = [interior]
        }
        
        let rawArray = interior as! [NSDictionary]
        
        guard type != nil else {
            return rawArray
        }
        
        for dictionary: NSDictionary in rawArray {
            if let object = type!.init(dictionary: dictionary) {
                objectArray.append(object)
            }
        }
        
        return objectArray
    }
    
    private func failWith(notification: String?, closure: ((NSError?) -> Void)?, error: NSError?) {
        
        if (notification == nil && closure == nil) {
            return;
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            
            if let note = notification {
                var userInfo : [String : AnyObject]?
                if (error != nil) {
                    userInfo = [APIController.dictionaryKeys.error : error!]
                }
                
                NSNotificationCenter.defaultCenter().postNotificationName(note, object: self, userInfo: userInfo)
            }
            
            if let block = closure {
                block(error)
            }
        }
    }
    
    private func succeedWith(notification: String?, closure: (([AnyObject]) -> Void)?, data: [AnyObject]) {
        
        assert(notification != nil || closure != nil)
        
        dispatch_async(dispatch_get_main_queue()) {
            if let note = notification {
                NSNotificationCenter.defaultCenter().postNotificationName(note, object: self, userInfo: [APIController.dictionaryKeys.data : data])
            }
            
            if let block = closure {
                block(data)
            }
        }
    }
}

extension NSNotification {
    
    func objectData() -> [AnyObject] {
        
        if (self.userInfo == nil) {
            return [AnyObject]()
        }
        
        return self.userInfo![APIController.dictionaryKeys.data] as! Array
    }
    
    func errorData() -> NSError? {
        
        return self.userInfo?[APIController.dictionaryKeys.error] as? NSError
    }
}

