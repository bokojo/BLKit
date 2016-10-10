//
//  ThingAPI.swift
//  BLKit
//
//  Created by Burton Lee on 4/18/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import UIKit

// MARK: - Model -

class Thing: APIModel {
    
    let name: String
    let thingID: Int
    
    init(name: String, thingID: Int) {
        self.name = name
        self.thingID = thingID
    }
    
    required convenience init?(dictionary: NSDictionary) {
        guard
            let name = dictionary["name"] as? String,
            let thingID = dictionary["id"] as? Int
        else { return nil }
        
        self.init(name: name, thingID: thingID)
    }
}

// MARK: - Controller -

class ThingAPI : APIController {
    
    init() {
        super.init(host:"http://thingserver.notaserver.com")
    }
    
    
    // MARK: - API DEFINITIONS -
    // MARK: GET - /thing/[id]
    
    func getThingFromServer(thingID: Int, success: @escaping (([AnyObject]) -> Void), failure: ((Error?) -> Void)?) {
        
        let parameters = APIParameters(
            
            urlString: "\(host)/thing/\(thingID)",
            successClosure: success,
            failureClosure: failure,
            type: Thing.self,
            jsonKey: "data.toomuchdata.things"
        )
        
        serverInteractionBy(parameters: parameters)
    }
}

// MARK: - View Controller -

class ExampleViewController : UIViewController {
    
    let apiController = ThingAPI()
    var data = [Thing]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let success = { (things: [AnyObject]) in
            self.data = things as! [Thing]
            
            // perform view update with fresh data
        }
        
        apiController.getThingFromServer(thingID: 0, success: success, failure: nil)
    }
    
}
