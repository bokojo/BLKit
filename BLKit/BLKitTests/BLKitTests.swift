//
//  BLKitTests.swift
//  BLKitTests
//
//  Created by Burton Lee on 4/14/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import XCTest
@testable import BLKit

class APIControllerTests: XCTestCase {
    
  
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Confirm logic paths are working
    
    func testBadURLFailure() {
        
        let expectation = self.expectation(description: "URL Test failed correctly.")
        let api = BLAPIController(host: "http://www.notanaddresszool.zool")
        let param = BLAPIController.APIParameters(
            urlString: "bad",
            successClosure: { (data: [AnyObject]) in XCTFail() },
            failureClosure: { (error: NSError?) in
                
                if error == nil {
                    expectation.fulfill()
                } else if let e = error {
                    print("Error localized description: \(e.localizedDescription)")
                    expectation.fulfill()
                }
            }
        )
        
        api.serverInteractionBy(parameters: param)
        
        self.waitForExpectations(timeout: 30.0, handler: { (error: Error?) -> Void in
                if error == nil { XCTAssert(true) } else { XCTFail() } })
    }
    
    // Parse Function tests
    func testParsingExclusions()
    {
        let goodDict = "{ \"conditions\" : \"good\", \"icon_url\" : \"url goes here\" }"
        let badDict = "{ \"other\" : \"bad dict\" }"
        let json = "[\(goodDict),\(badDict),\(goodDict),\(goodDict)]"
        let data = json.data(using: String.Encoding.ascii)
        
        
        let api = BLAPIController(host: "http://www.noserver.gov")
        let param = BLAPIController.APIParameters(
            urlString: "nothing",
            type: Weather.self
        )
        
        let parseFunc = api.defaultParseFunction()
        
        let output = try? parseFunc(data!, param)
        
        XCTAssert(output?.count == 3)
    }

    
    func testBadJSONKeyFailure() {
        
        let api = BLAPIController(host: "https://womp.womp")
        let parseFunc = api.defaultParseFunction()
        let param = BLAPIController.APIParameters(
            urlString: "blah",
            jsonKey: "this.is.a.bad.key"
        )
        
        let data = "{ \"key\" : \"value\" }".data(using: String.Encoding.utf8)
        do {
            _ = try parseFunc(data!, param)
        }
        catch BLAPIController.APIControllerErrors.BadJSONKey
        {
            XCTAssert(true, "BadJSONKey caught.")
        }
        catch
        {
            XCTFail("Other exception thrown. Failed test.")
        }
    }
   
    // Reachability needs replacing.
    
//    func testReachabilityQueueing() {
//        
//        let expectation1 = self.expectation(description: "Failed api call correctly")
//        let expectation2 = self.expectation(description: "Queued task for later")
//        let expectation3 = self.expectation(description: "Fulfilled task")
//        
//        let api = APIController(host: "http://api.wunderground.com/")
//        if (api.reachability == nil)
//        {
//            XCTFail("No reachability on API.")
//            return;
//        }
//        
//        let reachable = api.reachability!
//        
//        guard let unreachable = Reachability(hostname: "notaserver.gov") else
//        {
//            XCTFail("No bad reachability.")
//            return;
//        }
//        
//        let param = APIController.APIParameters(
//            urlString: "\(api.host)/api/5edc947d9938f768/forecast/q/CA/San_Francisco.json",
//            successClosure: { _ in
//                expectation3.fulfill()
//                print("--- Expectation 3 fulfilled")
//                XCTAssert(true)
//                
//            },
//            failureClosure: { _ in
//                expectation1.fulfill()
//                print("--- Expectation 1 fulfilled")
//                
//                if (api.commandQueue.count == 1)
//                {
//                    expectation2.fulfill()
//                }
//                
//                api.reachability = reachable
//                let processQueue = api.processQueue()
//                processQueue(reachable)
//            },
//            type: Weather.self,
//            jsonKey: "forecast.simpleforecast.forecastday",
//            queueOnFailure: true)
//        
//        api.reachability = unreachable
//        api.serverInteractionBy(parameters: param)
//        
//        self.waitForExpectations(timeout: 60.0, handler: { error in
//            if (error != nil)
//            {
//                XCTFail(error!.localizedDescription)
//            }
//        })
//        
//    }
    
    
    
    
}

