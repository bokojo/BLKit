//
//  APIController.swift
//  hack
//
//  Created by Burton Lee on 4/12/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import UIKit

// MARK: - Class: APIController
class APIController {
    
    var cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringCacheData
    var timeoutInterval = 30.0
    var host = ""
    
    enum HTTPVerb: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    enum APIControllerErrors: ErrorType {
        case BadJSONKey
    }
    
    func serverInteractionBy(urlString: String, successNotification: String?, failureNotification: String?, successClosure: (([AnyObject]) -> Void)?, failureClosure: ((NSError?) -> Void)?, type: APIObject.Type, jsonKey: String?, httpVerb: HTTPVerb?, inputObject: APIObject?) {
        
        if let url = NSURL(string:urlString) {
            
            let request = NSMutableURLRequest(URL: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
            request.HTTPMethod = httpVerb?.rawValue ?? HTTPVerb.GET.rawValue
            
            let task = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration()).dataTaskWithRequest(request) { (data, response, error) in
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
                    
                    if (error != nil || data == nil) {
                        
                        self.failWith(failureNotification, closure:failureClosure, error: error)
                        
                    } else {
                        
                        self.parseData(data!, jsonKey: jsonKey, type: type, successNotification: successNotification, failureNotification: failureNotification, successClosure: successClosure, failureClosure: failureClosure)
                    }
                }
            }
            
            task.resume()
            
        } else {
            
            assertionFailure("BAD URL: \(urlString)")
        }
    }
    
    private func parseData(data: NSData, jsonKey: String?, type: APIObject.Type, successNotification: String?, failureNotification: String?, successClosure:(([AnyObject]) -> Void)?, failureClosure:((NSError?) -> Void)?) {
        
        if let json = try? NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions()) {
            
            do {
                let objectArray = try self.processJSON(json, jsonKey: jsonKey, type: type)
                self.succeedWith(successNotification, closure: successClosure, data: objectArray)
                
            } catch APIControllerErrors.BadJSONKey {
                self.failWith(failureNotification, closure: failureClosure, error: NSError(domain: "APIController", code: 0, userInfo: ["reason" : "Bad JSON path key: \(jsonKey)", "json" : json]))
            } catch {
                self.failWith(failureNotification, closure: failureClosure, error: nil)
            }
            
        } else {
            
            self.failWith(failureNotification, closure: failureClosure, error: nil)
        }
        
    }
    
    private func processJSON(json: AnyObject, jsonKey: String?, type: APIObject.Type) throws -> [AnyObject]
    {
        var objectArray = [AnyObject]()
        var marker = json;
        
        if jsonKey != nil {
            
            let keysArray = jsonKey!.componentsSeparatedByString(".")
            
            for key in keysArray {
                
                if let d = marker[key] {
                    marker = d!;
                } else {
                    throw APIControllerErrors.BadJSONKey
                }
            }
        }
        
        if let interior = marker as? [NSDictionary] {
            
            for dictionary: NSDictionary in interior {
                
                if let object = type.init(dictionary: dictionary) {
                    
                    objectArray.append(object)
                }
            }
            
        } else if let interior = marker as? NSDictionary {
            
            if let object = type.init(dictionary: interior) {
                
                objectArray.append(object)
            }
        }
        
        return objectArray
    }
    
    private func failWith(notification: String?, closure: ((NSError?) -> Void)?, error: NSError?) {
        
        assert(notification != nil || closure != nil)
        
        dispatch_async(dispatch_get_main_queue()) {
            
            if let note = notification {
                var userInfo : [String : AnyObject]?
                if (error != nil) {
                    userInfo = ["error" : error!]
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
                NSNotificationCenter.defaultCenter().postNotificationName(note, object: self, userInfo: ["data" : data])
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
        
        return self.userInfo!["data"] as! Array
    }
    
    func errorData() -> NSError? {
        
        return self.userInfo?["error"] as? NSError
    }
}

