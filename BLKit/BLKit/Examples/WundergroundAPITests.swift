//
//  WundergroundAPITests.swift
//  BLKit
//
//  Created by Burton Lee on 10/10/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import XCTest
@testable import BLKit

class WundergroundAPITests: XCTestCase
{
    
    override func setUp()
    {
        super.setUp()
        
        continueAfterFailure = false
 
    }
    
    func testWeather()
    {
        
        let expectation = self.expectation(description: "Test Success in WUnderground API")
        let apiController = WeatherAPI()
        var data = [Weather]()
        
        let success = { (objects: [AnyObject]) in
            
            data = objects as! [Weather]
            
            expectation.fulfill()
            XCTAssert(data.count > 0)
        }
        
        let failure = { (error: NSError?) in
            if let e = error
            {
                print("\n\nLocalized Error: \(e.userInfo["reason"])\n\n")
                XCTFail()
            }
            else
            {
                XCTFail()
            }
        }
            
        _ = apiController.getSFWeather(success: success, failure: failure)
        
        self.waitForExpectations(timeout: 30.0, handler: { (error: Error?) in
            if error != nil
            {
                print("Localized error: \(error?.localizedDescription)")
            }
        })
    }
}
