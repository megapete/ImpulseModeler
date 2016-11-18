//
//  ConnectionDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class ConnectionDlog: NSWindowController
{
    @IBOutlet weak var theView: ConnectionDlogView!
    
    var model:[PCH_DiskSection]? = nil
    
    override var windowNibName: String!
    {
        return "ConnectionDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        guard let theModel = model
        else
        {
            return
        }
        
        theView.sections = theModel
        theView.fixFrameRect()
        
    }
    
    func runDialog(theModel:[PCH_DiskSection]) -> [(from:Int, to:Int)]?
    {
        self.model = theModel
        
        NSApp.runModal(for: self.window!)
        
        return nil
    }
}
