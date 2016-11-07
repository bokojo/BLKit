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
        (Data, APIParameters) throws -> [Any]
    
    public typealias completionFuncType =
        (Data?, URLResponse?, Error?) -> Void

    public struct APIParameters
    {
         public init(urlString: String,
              successNotification: Notification.Name? = nil,
              failureNotification: Notification.Name? = nil,
              successClosure: (([Any]) -> Void)? = nil,
              failureClosure: ((Error?) -> Void)? = nil,
              type: BLAPIModel.Type? = nil,
              jsonKey: String? = nil,
              httpVerb: httpVerb = .GET,
              uploadObject: BLAPIModelUploadable? = nil,
              cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy,
              timeoutInterval: Double = 60.0,
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
            self.uploadObject = uploadObject
            self.cachePolicy = cachePolicy
            self.timeoutInterval = timeoutInterval
            self.queueOnFailure = queueOnFailure
        }
        
        public let urlString: String
        public let successNotification: Notification.Name?
        public let failureNotification: Notification.Name?
        public let successClosure: (([Any]) -> Void)?
        public let failureClosure: ((Error?) -> Void)?
        public let type: BLAPIModel.Type?
        public let jsonKey: String?
        public let httpVerb: httpVerb
        public let uploadObject: BLAPIModelUploadable?
        public let cachePolicy: NSURLRequest.CachePolicy
        public let timeoutInterval: Double
        public let queueOnFailure: QueueBehavior
        
        public enum QueueBehavior: Int
        {
            case NoQueueing
            case FIFO
            case LastRequestOnly
            case LastUniqueRequest
            
        }
    }
    
    public let host: String
    
    public var reachability: Reachability?
    
    public lazy var commandQueue = [URLSessionTask]()
    
    public let urlSession = URLSession(configuration: URLSessionConfiguration.ephemeral)
    
    public init(host: String)
    {
        self.host = host;
        self.reachability = Reachability()
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
        case BadHTTPStatus
        static let domain = "APIController"
    }
    
    public func serverInteractionBy(parameters: APIParameters) -> URLSessionTask?
    {
        return self.serverInteractionBy(parameters: parameters, parseFunction: self.defaultParseFunction())
    }
    
    public func serverInteractionBy(parameters: APIParameters,
                                    parseFunction: @escaping parseFuncType) -> URLSessionTask?
    {
        guard let url = URL(string:parameters.urlString) else
        {
            assertionFailure("BAD URL: \(parameters.urlString)")
            return nil
        }
        
        var request = URLRequest(
            url: url,
            cachePolicy: parameters.cachePolicy,
            timeoutInterval: parameters.timeoutInterval)
        
        request.httpMethod = parameters.httpVerb.rawValue
        
        let completionFunc = self.completionHandler(
            parameters: parameters,
            parseFunction: parseFunction)
        
        var task: URLSessionTask
        switch (parameters.httpVerb)
        {
            case .GET:
                fallthrough
            case .DELETE:
                task = self.urlSession.dataTask(with: request, completionHandler: completionFunc)
            default:   // POST, PUT, PATCH
                task = self.urlSession.uploadTask(with: request, from: parameters.uploadObject?.postData, completionHandler: completionFunc)
        }
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
            
            // Basic connectivity
            if error != nil
            {
                self.failWith(
                    notification: parameters.failureNotification,
                    closure:parameters.failureClosure,
                    error: (error as! NSError))
                
            }
              
            if response != nil && response! is HTTPURLResponse
            {
                let hresponse = response as! HTTPURLResponse
                let value: Int = hresponse.statusCode as Int / 100
                if value >= 4
                {
                    self.failWith(
                        notification: parameters.failureNotification,
                        closure: parameters.failureClosure,
                        error: NSError(
                            domain: APIControllerErrors.domain,
                            code: APIControllerErrors.BadHTTPStatus.rawValue,
                            userInfo:
                            [NSLocalizedDescriptionKey : "Bad HTTP Status returned: \(hresponse.statusCode)\nURL: \(hresponse.url)", "response" : hresponse]))
                }
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
    
    public final func defaultParseFunction() -> (Data, APIParameters) throws -> [Any]
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
                    if let d = (interior as! [AnyHashable : Any])[key]
                    {
                        interior = d;
                    }
                    else
                    {
                        throw APIControllerErrors.BadJSONKey
                    }
                }
            }
            
            if interior is [AnyHashable : Any]
            {
                interior = [interior]
            }
            
            let rawArray = interior as! [ [AnyHashable : Any] ]
            
            var objectArray = [Any!]()
            
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
                              closure: ((Error?) -> Void)?,
                              error: Error?)
    {
        if notification == nil && closure == nil
        {
            return;
        }
        
        DispatchQueue.main.async
        {
            if let note = notification
            {
                var userInfo : [String : Any]?
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
                                 closure: (([Any]) -> Void)?,
                                 data: [Any])
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
    
    public func addTaskToQueue(task: URLSessionTask, parameters: APIParameters)
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
    public func objectData() -> [Any]?
    {
        if self.userInfo == nil
        {
            return [Any]()
        }
        return self.userInfo![BLAPIController.dictionaryKeys.data] as? Array ?? [Any]()
    }
    
    public func errorData() -> Error?
    {
        return self.userInfo?[BLAPIController.dictionaryKeys.error] as! Error?
    }
}

