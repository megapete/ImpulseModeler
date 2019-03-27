//
//  ConnectionDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class ConnectionDlog: NSWindowController, NSWindowDelegate
{
    @IBOutlet weak var theView: ConnectionDlogView!
    
    @IBOutlet var popUpConn: NSMenu!
    
    
    var result:[(from:Int, to:[Int])]? = nil
    
    var model:[PCH_DiskSection]? = nil
    
    override var windowNibName: NSNib.Name!
    {
        return "ConnectionDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        // Note that per the documentation, this function will be called after the awakeFromNib message is sent to all the objects in the nib file.
        
        guard let theModel = model
        else
        {
            return
        }
        
        theView.sections = theModel
        
        theView.connectionPopUp = self.popUpConn
        theView.setUpView()
    }
    
    func windowDidResize(_ notification: Notification)
    {
        theView.fixFrameRect()
        theView.needsDisplay = true
    }
    
    func runDialog(theModel:[PCH_DiskSection]) -> [(from:Int, to:[Int])]?
    {
        self.model = theModel
        
        NSApp.runModal(for: self.window!)
        
        return self.result
    }
    
    @IBAction func handleShoot(_ sender: Any)
    {
        var connections:[(from:Int, to:[Int])] = Array()
        
        for nextNode in theView.nodes
        {
            if nextNode.idNum >= 0 && nextNode.connections.count > 0
            {
                let connection = (from:nextNode.idNum, to:nextNode.connections)
                connections.append(connection)
            }
        }
        
        self.result = connections
        
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    
    @IBAction func handleCancel(_ sender: Any)
    {
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func handleResetAll(_ sender: Any)
    {
        theView.resetAllConnections()
    }
    
    @IBAction func handleConnectToGround(_ sender: Any)
    {
        self.theView.connectSpecial(toNode: -1)
    }
    
    @IBAction func handleConnectToImpulse(_ sender: Any)
    {
        self.theView.connectSpecial(toNode: -2)
    }
    
}
