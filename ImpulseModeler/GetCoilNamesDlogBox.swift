//
//  GetCoilNamesDlogBox.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2019-10-23.
//  Copyright © 2019 Peter Huber. All rights reserved.
//
// First test of my first base class, PCH_DialogBox.

import Foundation
import Cocoa

class GetCoilNamesDlogBox:PCH_DialogBox
{
    @IBOutlet var coil1Name: NSTextField!
    @IBOutlet var coil2Name: NSTextField!
    @IBOutlet var coil3Name: NSTextField!
    @IBOutlet var coil4Name: NSTextField!
    @IBOutlet var coil5Name: NSTextField!
    @IBOutlet var coil6Name: NSTextField!
    @IBOutlet var coil7Name: NSTextField!
    @IBOutlet var coil8Name: NSTextField!
    
    let numCoils:Int
    
    var namesArray:[String] {
        get
        {
            if !self.setupIsDone
            {
                return []
            }
            
            var result:[String] = []
            
            let coilNames = [coil1Name, coil2Name, coil3Name, coil4Name, coil5Name, coil6Name, coil7Name, coil8Name]
            
            for i in 0..<self.numCoils
            {
                result.append(coilNames[i]!.stringValue)
            }
            
            return result
        }
    }
    
    init(numCoils:Int)
    {
        self.numCoils = min(8, numCoils)
        
        super.init(viewNibFileName: "GetCoilNames", windowTitle: "Coil Names", hideCancel: false)
        
        do
        {
            try SetupDialogBox()
            
            let coilNames = [coil1Name, coil2Name, coil3Name, coil4Name, coil5Name, coil6Name, coil7Name, coil8Name]
            
            for i in 0..<8
            {
                coilNames[i]!.stringValue = "V\(i+1)"
                
                if i >= numCoils
                {
                    coilNames[i]!.isEnabled = false
                }
            }
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
        }
    }
    
    
    
}
