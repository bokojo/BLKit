//
//  ThingAPI.swift
//  BLKit
//
//  Created by Burton Lee on 4/18/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import UIKit

class Thing: APIObject {
    
    required convenience init?(dictionary: NSDictionary) {
        self.init()
    }
}

class ThingAPI : APIController {
    
    override init() {
        super.init()
        
        host = "http://thingserver.notaserver.com"
    }
    
    // MARK: - API DEFINITIONS -
    // MARK: GET - /thing/[id]
    
    func getThingFromServer(thingID: Int, success: (([AnyObject]) -> Void), failure: ((NSError?) -> Void)?) {
        
        let parameters = apiParameters(
            
            urlString: "/thing/\(thingID)",
            successClosure: success,
            failureClosure: failure,
            type: Thing.self,
            jsonKey: "data.toomuchdata.things"
        )
        
        serverInterationBy(parameters)
    }
}

class ExampleViewController : UIViewController {
    
    let apiController = ThingAPI()
    var data = [Thing]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let success = { (things: [AnyObject]) in
            self.data = things as! [Thing]
            
            // perform view update with fresh data
        }
        
        apiController.getThingFromServer(0, success: success, failure: nil)
    }
    
}
