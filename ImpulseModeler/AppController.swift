//
//  AppController.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class AppController: NSObject {

    var phaseDefinition:Phase?
    
    
    
    // Menu Handlers
    @IBAction func handleNew(_ sender: AnyObject)
    {
        DLog("Handling New menu command")
        
        if (self.phaseDefinition != nil)
        {
            // TODO: Ask user if he wants to save the current phase before deleteing it
            DLog("Deleting existing phase")
            self.phaseDefinition = nil
        }
        
        // Bring up the core dialog
        let coreDlog = CoreInputDlog()
        
        let testCore = Core(diameter:20.0, height:50.0, htFactor:3.0, coilCenterOffset:3.5)
        guard let newCore = coreDlog.runDialog(testCore)
        else
        {
            DLog("No core defined!")
            return
        }
        
        DLog("Core diameter: \(newCore.diameter), Window height: \(newCore.height), Height factor: \(newCore.htFactor)")
        
    }
}
