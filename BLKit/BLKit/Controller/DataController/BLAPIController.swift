//
//  APIController.swift
//  hack
//
//  Created by Burton Lee on 4/12/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation


open class BLAPIController
{
    public typealias parseFuncType =
        (Data, APIParameters) throws -> [AnyObject]
    
    public typealias completionFuncType =
        (Data?, URLResponse?, Error?) -> Void

    public class APIParameters
    {
         init(urlString: String,
              successNotification: Notification.Name? = nil,
              failureNotification: Notification.Name? = nil,
              successClosure: (([AnyObject]) -> Void)? = nil,
              failureClosure: ((NSError?) -> Void)? = nil,
              type: BLAPIModel.Type? = nil,
              jsonKey: String? = nil,
              httpVerb: httpVerb? = nil,
              inputObject: BLAPIModel? = nil,
              cachePolicy: NSURLRequest.CachePolicy? = nil,
              timeoutInterval: Double? = nil,
              queueOnFailure: Bool = false)
        {
            
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
        let failureClosure: ((NSError?) -> Void)?
        let type: BLAPIModel.Type?
        let jsonKey: String?
        let httpVerb: httpVerb?
        let inputObject: BLAPIModel?
        let cachePolicy: NSURLRequest.CachePolicy?
        let timeoutInterval: Double?
        let queueOnFailure: Bool
    }
    
    let defaultCachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy
    
    let defaultTimeoutInterval = 60.0
    
    let host: String
    
    var reachability: Reachability?
    
    lazy var commandQueue = [URLSessionTask]()
    
    let urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral)
    
    init(host: String)
    {
        self.host = host;
        self.reachability = Reachability(hostname: self.host)
        
        if self.reachability != nil
        {
            self.reachability!.whenReachable = self.processQueue()
        }
    }
    
    deinit
    {
        self.reachability = nil
        self.commandQueue.removeAll()
        self.urlSession.invalidateAndCancel()
    }
    
    struct dictionaryKeys
    {
        static let data = "data"
        static let error = "error"
        static let json = "json"
        static let rawData = "rawdata"
        static let reason = "reason"
    }
    
    enum httpVerb: String
    {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    enum APIControllerErrors: Int, Error
    {
        case BadJSONKey = 101
        case UnreachableServer
        case EmptyDataSet
        static let domain = "APIController"
    }
    
    func serverInteractionBy(parameters: APIParameters)
    {
        self.serverInteractionBy(parameters: parameters, parseFunction: self.defaultParseFunction())
    }
    
    func serverInteractionBy(parameters: APIParameters,
                                    parseFunction: @escaping parseFuncType)
    {
        if let url = URL(string:parameters.urlString)
        {
            var request = URLRequest(
                url: url,
                cachePolicy: parameters.cachePolicy ?? self.defaultCachePolicy,
                timeoutInterval: parameters.timeoutInterval ?? self.defaultTimeoutInterval)
            
            request.httpMethod = parameters.httpVerb?.rawValue ?? httpVerb.GET.rawValue
            
            let completionFunc = self.completionHandler(
                parameters: parameters,
                parseFunction: parseFunction)
            
            let task = self.urlSession.dataTask(with: request, completionHandler: completionFunc)
        
            if let reach = self.reachability
            {
                guard reach.isReachable else
                {
                    if let cachedResponse = URLCache.shared.cachedResponse(for: request)
                    {
                        completionFunc(cachedResponse.data, cachedResponse.response, nil)
                    }
                    else
                    {
                        self.failWith(
                            notification: parameters.failureNotification,
                            closure: parameters.failureClosure,
                            error: NSError(
                                domain: APIControllerErrors.domain,
                                code: APIControllerErrors.UnreachableServer.rawValue,
                                userInfo:
                                [BLAPIController.dictionaryKeys.reason :
                                    "Unreachable Host: \(self.host)"]))
                    }
                
                    if parameters.queueOnFailure
                    {
                        self.commandQueue.append(task)
                    }
                    
                    return;
                }
                
                task.resume()
            }
        }
        else
        {
            assertionFailure("BAD URL: \(parameters.urlString)")
        }
    }
    
    func completionHandler(parameters: APIParameters,
                                parseFunction: @escaping parseFuncType) -> completionFuncType
    {
        return { (data, response, error) in
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async
            {
                if error != nil
                {
                    self.failWith(
                        notification: parameters.failureNotification,
                        closure:parameters.failureClosure,
                        error: (error as! NSError))
                        
                }
                else if data == nil
                {
                    self.failWith(
                        notification: parameters.failureNotification,
                        closure: parameters.failureClosure,
                        error: NSError(
                            domain: APIControllerErrors.domain,
                            code: APIControllerErrors.EmptyDataSet.rawValue,
                            userInfo:
                                [BLAPIController.dictionaryKeys.reason :
                                    "No Data Returned at NSURLSession"]))
                }
                else
                {
                    do
                    {
                        let models = try parseFunction(data!, parameters)
                        self.succeedWith(
                            notification: parameters.successNotification,
                            closure: parameters.successClosure, data: models)
                    }
                    catch APIControllerErrors.BadJSONKey
                    {
                        self.failWith(
                            notification: parameters.failureNotification,
                            closure: parameters.failureClosure,
                            error: NSError(
                                domain: APIControllerErrors.domain,
                                code: APIControllerErrors.BadJSONKey.rawValue,
                                userInfo:
                                    [BLAPIController.dictionaryKeys.reason :
                                        "Bad JSON path key: \(parameters.jsonKey)",
                                    BLAPIController.dictionaryKeys.json :
                                        parameters.jsonKey!]))
                            
                    }
                    catch
                    {
                        self.failWith(
                            notification: parameters.failureNotification,
                            closure: parameters.failureClosure,
                            error:nil)
                    }
                }
            }
        }
    }
    
    final func defaultParseFunction() -> (Data, APIParameters) throws -> [AnyObject]
    {
        return { (data, parameters) in
            
            let json = try JSONSerialization.jsonObject(
                with: data,
                options:JSONSerialization.ReadingOptions())
            
            var interior = json
            
            if parameters.jsonKey != nil
            {
                let keysArray = parameters.jsonKey!.components(separatedBy:".")
                
                for key in keysArray
                {
                    if let d = (interior as! NSDictionary)[key]
                    {
                        interior = d;
                    }
                    else
                    {
                        throw APIControllerErrors.BadJSONKey
                    }
                }
            }
            
            if interior is NSDictionary
            {
                interior = [interior]
            }
            
            let rawArray = interior as! [NSDictionary]
            
            var objectArray = [AnyObject!]()
            
            if let type = parameters.type
            {
                objectArray = rawArray.map { type.init(dictionary: $0) }.filter { $0 != nil }
            }
            else
            {
                objectArray = rawArray
            }
            
            return objectArray
        }
    }

    fileprivate func failWith(notification: Notification.Name?,
                              closure: ((NSError?) -> Void)?,
                              error: NSError?)
    {
        if notification == nil && closure == nil
        {
            return;
        }
        
        DispatchQueue.main.async
        {
            if let note = notification
            {
                var userInfo : [String : AnyObject]?
                if error != nil
                {
                    userInfo = [BLAPIController.dictionaryKeys.error : error! as NSError]
                }
                    
                NotificationCenter.default.post(
                    name: note,
                    object: self,
                    userInfo: userInfo)
            }
                
            if let block = closure
            {
                block(error)
            }
        }
    }
    
    fileprivate func succeedWith(notification: Notification.Name?,
                                 closure: (([AnyObject]) -> Void)?,
                                 data: [AnyObject])
    {
        assert(notification != nil || closure != nil)
        
        DispatchQueue.main.async
        {
            if let note = notification
            {
                NotificationCenter.default.post(
                    name: note,
                    object: self,
                    userInfo: [BLAPIController.dictionaryKeys.data : data])
            }
                
            if let block = closure
            {
                block(data)
            }
        }
    }
    
    func processQueue() -> (Reachability) -> Void
    {
        return { [unowned self] (reachability) in
            if self.commandQueue.count > 0
            {
                var newQueue = [URLSessionTask]()
                
                for task in self.commandQueue
                {
                    if reachability.isReachable
                    {
                        task.resume()
                    }
                    else
                    {
                        newQueue.append(task)
                    }
                }
                
                self.commandQueue = newQueue;
            }
        }
    }
}

public extension Notification
{
    
    func objectData() -> [AnyObject]?
    {
        if self.userInfo == nil
        {
            return [AnyObject]()
        }
        return self.userInfo![BLAPIController.dictionaryKeys.data] as? Array
    }
    
    func errorData() -> NSError?
    {
        return self.userInfo?[BLAPIController.dictionaryKeys.error] as? NSError
    }
}

