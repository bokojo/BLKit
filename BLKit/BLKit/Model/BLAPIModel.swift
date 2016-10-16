//
//  APIObject.swift
//  hack
//
//  Created by Burton Lee on 4/14/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation

public protocol BLAPIModel {
    
    init?(dictionary: [AnyHashable : Any])
}

public protocol BLAPIModelUploadable: BLAPIModel {
    
    var postData: Data? { get }
}
