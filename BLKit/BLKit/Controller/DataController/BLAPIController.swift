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
         public init(urlString: String,
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
              queueOnFailure: QueueBehavior = .NoQueueing)
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
        
        public let urlString: String
        public let successNotification: Notification.Name?
        public let failureNotification: Notification.Name?
        public let successClosure: (([AnyObject]) -> Void)?
        public let failureClosure: ((NSError?) -> Void)?
        public let type: BLAPIModel.Type?
        public let jsonKey: String?
        public let httpVerb: httpVerb?
        public let inputObject: BLAPIModel?
        public let cachePolicy: NSURLRequest.CachePolicy?
        public let timeoutInterval: Double?
        public let queueOnFailure: QueueBehavior
        
        public enum QueueBehavior: Int
        {
            case NoQueueing
            case FIFO
            case LastRequestOnly
            case LastUniqueRequest
            
        }
    }
    
    public let defaultCachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy
    
    public let defaultTimeoutInterval = 60.0
    
    public let host: String
    
    public var reachability: Reachability?
    
    public lazy var commandQueue = [URLSessionTask]()
    
    public let urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral)
    
    public init(host: String)
    {
        self.host = host;
        self.reachability = Reachability(hostname: self.host)
        self.configureReachability()
    }
    
    deinit
    {
        self.reachability = nil
        self.commandQueue.removeAll()
        self.urlSession.invalidateAndCancel()
    }
    
    public struct dictionaryKeys
    {
        static let data = "data"
        static let error = "error"
        static let json = "json"
        static let rawData = "rawdata"
    }
    
    public enum httpVerb: String
    {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    public enum APIControllerErrors: Int, Error
    {
        case BadJSONKey = 101
        case UnreachableServer
        case EmptyDataSet
        static let domain = "APIController"
    }
    
    public func serverInteractionBy(parameters: APIParameters) -> URLSessionDataTask?
    {
        return self.serverInteractionBy(parameters: parameters, parseFunction: self.defaultParseFunction())
    }
    
    public func serverInteractionBy(parameters: APIParameters,
                                    parseFunction: @escaping parseFuncType) -> URLSessionDataTask?
    {
        guard let url = URL(string:parameters.urlString) else
        {
            assertionFailure("BAD URL: \(parameters.urlString)")
            return nil
        }
        
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
            if reach.isReachable == false
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
                            [NSLocalizedDescriptionKey :
                                "Unreachable Host: \(self.host)"]))
                }
                
                if parameters.queueOnFailure != .NoQueueing
                {
                    self.addTaskToQueue(task: task, parameters: parameters)
                }
                
                return task
            }
        }
        
        task.resume()
        return task
    }

    public func completionHandler(parameters: APIParameters,
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
                                [NSLocalizedDescriptionKey :
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
                                    [NSLocalizedDescriptionKey :
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
    
    public final func defaultParseFunction() -> (Data, APIParameters) throws -> [AnyObject]
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
    
    public func processQueue() -> (Reachability) -> Void
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
    
    public func addTaskToQueue(task: URLSessionDataTask, parameters: APIParameters)
    {
        switch parameters.queueOnFailure
        {
            case .NoQueueing:
                break;
            
            case .LastRequestOnly:
                self.commandQueue = [task]
            
            case .LastUniqueRequest:
                var newQueue = self.commandQueue.filter() { queuedTask in return queuedTask.currentRequest?.url != task.currentRequest?.url }
                newQueue.append(task)
                self.commandQueue = newQueue
            
            case .FIFO:
                self.commandQueue.append(task)
        }
        
    }
    
    func configureReachability()
    {
        if self.reachability != nil
        {
            self.reachability!.whenReachable = self.processQueue()
            do { try self.reachability!.startNotifier() } catch {}
        }
    }
}
    

public extension Notification
{
    
    public func objectData() -> [AnyObject]?
    {
        if self.userInfo == nil
        {
            return [AnyObject]()
        }
        return self.userInfo![BLAPIController.dictionaryKeys.data] as? Array
    }
    
    public func errorData() -> NSError?
    {
        return self.userInfo?[BLAPIController.dictionaryKeys.error] as? NSError
    }
}

