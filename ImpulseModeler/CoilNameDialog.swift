//
//  CoilNameDialog.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2019-10-21.
//  Copyright © 2019 Peter Huber. All rights reserved.
//

import Cocoa

class CoilNameDialog: NSWindowController {
    
    private var numCoils:Int = 0
    
    var tWindow:NSWindow? = nil
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        DLog("Window has loaded")
    }
    
    func SetNumCoils(numCoils:Int)
    {
        DLog("Accessing window property")
        tWindow = self.window
        self.numCoils = numCoils
    }
    
}
