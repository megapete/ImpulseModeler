//
//  CoreInputDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class CoreInputDlog: NSWindowController {

    var core:Core?
    
    @IBOutlet weak var coreDiameterField: NSTextField!
    var coreDiameter = 0.0
    @IBOutlet weak var windowHtField: NSTextField!
    var windowHt = 0.0
    @IBOutlet weak var htFactorField: NSTextField!
    var heightFactor = 0.0
    @IBOutlet weak var coilCtrOffsetField: NSTextField!
    var coilCtrOffset = 0.0
    
    @IBOutlet var threeXbutton: NSButton!
    @IBOutlet var oneXbutton: NSButton!
    @IBOutlet var otherXbutton: NSButton!
    
    // 1=1.0, 2=otherField, 3=3.0
    var htFactor:Int?
    
    
    // This was the easiest way I could find to just show the associated xib file (see the 3rd response at http://stackoverflow.com/questions/24220638/subclassing-nswindowcontroller-in-swift-and-initwindownibname
    override var windowNibName: NSNib.Name!
    {
        return "CoreInputDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        if (self.htFactor == 3)
        {
            threeXbutton.state = .on
        }
        else if (self.htFactor == 1)
        {
            oneXbutton.state = .on
        }
        else
        {
            otherXbutton.state = .on
            htFactorField.isEnabled = true
        }
        
        coreDiameterField.doubleValue = coreDiameter
        windowHtField.doubleValue = windowHt
        coilCtrOffsetField.doubleValue = coilCtrOffset
        htFactorField.doubleValue = heightFactor

    }
    
    // This is the function that should be called to conduct the dialog
    func runDialog(_ usingCore:Core?) -> Core?
    {
        if let oldCore = usingCore
        {
            coreDiameter = oldCore.diameter
            windowHt = oldCore.height
            coilCtrOffset = oldCore.coilCenterOffset
            heightFactor = oldCore.htFactor
            
            if oldCore.htFactor == 3.0
            {
                self.htFactor = 3
            }
            else if oldCore.htFactor == 1.0
            {
                self.htFactor = 1
            }
            else
            {
                self.htFactor = 2
            }
        }
        else
        {
            self.htFactor = 3
        }
        
        NSApp.runModal(for: self.window!)
        
        return self.core
    }
    
    // Button handlers
    @IBAction func okButtonPushed(_ sender: AnyObject)
    {
        DLog("Ok button pushed")
        
        self.core = Core(diameter: self.coreDiameterField.doubleValue, height: self.windowHtField.doubleValue, legCenters: 0.0, htFactor: (self.htFactor! == 2 ? self.htFactorField.doubleValue : Double(self.htFactor!)), coilCenterOffset: self.coilCtrOffsetField.doubleValue)
                
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func cancelButtonPushed(_ sender: AnyObject)
    {
        DLog("Cancel button pushed")
        self.core = nil
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func handleHtFactorGroup(_ sender: AnyObject)
    {
        guard let wButton:NSButton = sender as? NSButton else
        {
            return
        }
        
        if (wButton == self.threeXbutton)
        {
            self.htFactor = 3
            self.htFactorField.isEnabled = false
        }
        else if (wButton == self.oneXbutton)
        {
            self.htFactor = 1
            self.htFactorField.isEnabled = false
        }
        else if (wButton == self.otherXbutton)
        {
            self.htFactor = 2
            self.htFactorField.isEnabled = true
        }
    }
    
}
