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
    
    @IBOutlet var coreDiameterField: NSTextField!
    @IBOutlet var windowHtField: NSTextField!
    @IBOutlet var htFactorField: NSTextField!
    
    @IBOutlet var threeXbutton: NSButton!
    @IBOutlet var oneXbutton: NSButton!
    @IBOutlet var otherXbutton: NSButton!
    
    var htFactor:Int?
    
    
    // This was the easiest way I could find to just show the associated xib file (see the 3rd response at http://stackoverflow.com/questions/24220638/subclassing-nswindowcontroller-in-swift-and-initwindownibname
    override var windowNibName: String!
    {
        return "CoreInputDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    // This is the function that should be called to conduct the dialog
    func runDialog(_ usingCore:Core?) -> Core?
    {
        if let oldCore = usingCore
        {
            coreDiameterField.stringValue = "\(oldCore.diameter)"
            windowHtField.stringValue = "\(oldCore.height)"
            
            if (oldCore.htFactor == 3.0)
            {
                threeXbutton.state = NSOnState
            }
            else if (oldCore.htFactor == 1.0)
            {
                oneXbutton.state = NSOnState
            }
            else
            {
                otherXbutton.state = NSOnState
                htFactorField.stringValue = "\(oldCore.htFactor)"
            }
        }
        else
        {
            threeXbutton.state = NSOnState
        }
        
        let result = NSApp.runModal(for: self.window!)
        
        return core
    }
    
    // Button handlers
    @IBAction func okButtonPushed(_ sender: AnyObject)
    {
        DLog("Ok button pushed")
        self.core = nil
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
    }
    
}
