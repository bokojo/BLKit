//
//  BLViewController.swift
//  BLKit
//
//  Created by Burton Lee on 10/15/16.
//  Copyright © 2016 Buffalo Ladybug LLC. All rights reserved.
//

import Foundation

open class BLViewController: UIViewController
{
    open func fetchData()
    {
        
    }
    
    open func display(data: [AnyObject])
    {
        
    }
    
    open func display(error: Error?)
    {
        
    }
    
    public func mkSuccess() -> (([AnyObject]) -> Void)
    {
        return mkSuccess(nil)
    }
    
    public func mkSuccess(_ c: (([AnyObject]) -> Void)? ) -> (([AnyObject]) -> Void)
    {
        return { [weak self] data in
            
            guard self != nil else { return }
            self!.display(data: data)
            
            if let closure = c { closure(data) }
        }
    }
    
    public func mkFailure() -> ((Error?) -> Void)
    {
        return mkFailure(nil)
    }
    
    public func mkFailure(_ c: ((Error?) -> Void)? ) -> ((Error?) -> Void)
    {
        return { [weak self] error in
            
            guard self != nil else { return }
            self!.display(error: error)
            
            if let closure = c { closure(error) }
            
        }
    }
}
