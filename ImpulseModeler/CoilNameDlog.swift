//
//  CoilNameDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2019-10-21.
//  Copyright © 2019 Peter Huber. All rights reserved.
//

import Cocoa

class CoilNameDlog: NSWindowController {

    @IBOutlet var coil1name: NSTextField!
    @IBOutlet var coil2name: NSTextField!
    @IBOutlet var coil3name: NSTextField!
    @IBOutlet var coil4name: NSTextField!
    @IBOutlet var coil5name: NSTextField!
    @IBOutlet var coil6name: NSTextField!
    @IBOutlet var coil7name: NSTextField!
    @IBOutlet var coil8name: NSTextField!
    
    var numCoils:Int = 0
    
    var runFlag = false
    
    var names:[String] = []
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        if self.runFlag
        {
            self.ResetFields()
            
            if numCoils > 0
            {
                coil1name.isEnabled = true
            }
            if numCoils > 1
            {
                coil2name.isEnabled = true
            }
            if numCoils > 2
            {
                coil3name.isEnabled = true
            }
            if numCoils > 3
            {
                coil4name.isEnabled = true
            }
            if numCoils > 4
            {
                coil5name.isEnabled = true
            }
            if numCoils > 5
            {
                coil6name.isEnabled = true
            }
            if numCoils > 6
            {
                coil7name.isEnabled = true
            }
            if numCoils > 7
            {
                coil8name.isEnabled = true
            }
            
            self.showWindow(nil)
            NSApp.runModal(for: self.window!)
        }
        
        self.runFlag = false
    }
    
    func ResetFields()
    {
        coil1name.isEnabled = false
        coil2name.isEnabled = false
        coil3name.isEnabled = false
        coil4name.isEnabled = false
        coil5name.isEnabled = false
        coil6name.isEnabled = false
        coil7name.isEnabled = false
        coil8name.isEnabled = false
    }
    
   
    
    func SetNumCoilsAndRun(numCoils:Int)
    {
        self.numCoils = numCoils
        
        if let dlogWindow = self.window
        {
            self.ResetFields()
            
            if numCoils > 0
            {
                coil1name.isEnabled = true
            }
            if numCoils > 1
            {
                coil2name.isEnabled = true
            }
            if numCoils > 2
            {
                coil3name.isEnabled = true
            }
            if numCoils > 3
            {
                coil4name.isEnabled = true
            }
            if numCoils > 4
            {
                coil5name.isEnabled = true
            }
            if numCoils > 5
            {
                coil6name.isEnabled = true
            }
            if numCoils > 6
            {
                coil7name.isEnabled = true
            }
            if numCoils > 7
            {
                coil8name.isEnabled = true
            }
            
            self.showWindow(nil)
            NSApp.runModal(for: dlogWindow)
        }
        else
        {
            self.runFlag = true
        }
    }
    
    @IBAction func handleOkay(_ sender: Any)
    {
        if numCoils > 0
        {
            self.names.append(coil1name.stringValue)
        }
        if numCoils > 1
        {
            self.names.append(coil2name.stringValue)
        }
        if numCoils > 2
        {
            self.names.append(coil3name.stringValue)
        }
        if numCoils > 3
        {
            self.names.append(coil4name.stringValue)
        }
        if numCoils > 4
        {
            self.names.append(coil5name.stringValue)
        }
        if numCoils > 5
        {
            self.names.append(coil6name.stringValue)
        }
        if numCoils > 6
        {
            self.names.append(coil7name.stringValue)
        }
        if numCoils > 7
        {
            self.names.append(coil8name.stringValue)
        }
        
        
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func handleCancel(_ sender: Any)
    {
        self.names = []
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
}
