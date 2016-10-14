//
//  WundergroundAPI.swift
//  BLKit
//
//  Created by Burton Lee on 4/18/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

//  Example implementation of a simple API; not a complete or proper WUnderground
// 

import UIKit

// MARK: - Model -

class Weather: APIModel {
    
    // Required properties;  can also be optional
    let conditions: String
    let icon_url: String
    
    init(conditions: String, icon_url: String) {
        self.conditions = conditions
        self.icon_url = icon_url
    }
    
    required convenience init?(dictionary: NSDictionary) {
        // guard for required; equally possible to assign and pass incomplete
        // object
        guard
            let conditions = dictionary["conditions"] as? String,
            let icon_url = dictionary["icon_url"] as? String
        else { return nil }
        
        self.init(conditions: conditions, icon_url: icon_url)
    }
}

// MARK: - Controller -

class WeatherAPI : APIController {
    
    let WeatherUndergroundAPIKey = "5edc947d9938f768"
    
    // http://api.wunderground.com/api/5edc947d9938f768/forecast/q/CA/San_Francisco.json
    
    init() {
        super.init(host:"https://api.wunderground.com/")
    }
    
    
    // MARK: - API DEFINITIONS -
    // MARK: GET - /thing/[id]
    
    func getSFWeather(success: @escaping (([AnyObject]) -> Void), failure: ((NSError?) -> Void)?) {
        
        let parameters = APIParameters(
            
            urlString: "\(host)api/\(WeatherUndergroundAPIKey)/forecast/q/CA/San_Francisco.json",
            successClosure: success,
            failureClosure: failure,
            type: Weather.self,
            jsonKey: "forecast.simpleforecast.forecastday"
        )
        
        serverInteractionBy(parameters: parameters)
    }
}

// MARK: - View Controller -

class ExampleViewController : UIViewController {
    
    let apiController = WeatherAPI()
    var data = [Weather]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let conditions_label = UILabel(frame: CGRect(x: 40.0, y: 40.0, width: 200.0, height: 60.0))
        let url_label = UILabel(frame: CGRect(x: 40.0, y: 100.0, width: 200.0, height: 60.0))
        
        self.view.addSubview(conditions_label)
        self.view.addSubview(url_label)
        
        let success = { [unowned self] (objects: [AnyObject]) in
            self.data = objects as! [Weather]
            
            if let weather = self.data.first {
                conditions_label.text = weather.conditions
                url_label.text = weather.icon_url
            }
        }
        
        let failure = { [unowned conditions_label, unowned url_label] (error: Error?) in
            
            conditions_label.text = "Unable to fetch weather."
            url_label.isHidden = true
            
        }
        
        apiController.getSFWeather(success: success, failure: failure)
    }
    
}
