//
//  APIObject.swift
//  hack
//
//  Created by Burton Lee on 4/14/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation

protocol APIObject : AnyObject {
    
    init?(dictionary: NSDictionary)
}
