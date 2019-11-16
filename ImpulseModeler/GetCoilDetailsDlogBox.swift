//
//  GetCoilDetailsDlogBox.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2019-10-23.
//  Copyright © 2019 Peter Huber. All rights reserved.
//

import Cocoa

class GetCoilDetailsDlogBox: PCH_DialogBox {

    @IBOutlet weak var oneSectionPerDisk: NSButton!
    @IBOutlet weak var oneSection: NSButton!
    @IBOutlet weak var twoSections: NSButton!
    @IBOutlet weak var fourSections: NSButton!
    @IBOutlet weak var customSections: NSButton!
    @IBOutlet weak var numCustomSections: NSTextField!
    
    @IBOutlet weak var topStaticRing: NSButton!
    @IBOutlet weak var centerStaticRing: NSButton!
    @IBOutlet weak var bottomStaticRing: NSButton!
    
    @IBOutlet weak var wdgRing: NSButton!
    
    @IBOutlet weak var lineAtTop: NSButton!
    @IBOutlet weak var lineAtCenter: NSButton!
    @IBOutlet weak var regulatingWdg: NSButton!
    
    @IBOutlet weak var noInterleave: NSButton!
    @IBOutlet weak var fullInterleave: NSButton!
    @IBOutlet weak var partialInterleave: NSButton!
    @IBOutlet weak var numPartialDisks: NSTextField!
    @IBOutlet weak var partialDiskLabel: NSTextField!
    
    @IBOutlet weak var windingRing: NSButton!
    @IBOutlet weak var ringDisk1: NSTextField!
    @IBOutlet weak var ringDisk2: NSTextField!
    @IBOutlet weak var betweenAndLabel: NSTextField!
    
    
    init(coilName:String)
    {
        super.init(viewNibFileName: "GetCoilDetails", windowTitle: "Coil Details for \(coilName)", hideCancel: true)
        
        do
        {
            try SetupDialogBox()
            
            // set default starting values for the radio button groups
            self.lineAtTop.state = .on
            self.noInterleave.state = .on
            self.oneSectionPerDisk.state = .on

            self.SetControlEnables()
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
        }
    }
    
    func SetControlEnables()
    {
        if self.partialInterleave.state == .on
        {
            self.numPartialDisks.isEnabled = true
            self.partialDiskLabel.isEnabled = true
        }
        else
        {
            self.numPartialDisks.isEnabled = false
            self.partialDiskLabel.isEnabled = false
        }
        
        if self.windingRing.state == .on
        {
            self.ringDisk1.isEnabled = true
            self.ringDisk2.isEnabled = true
            self.betweenAndLabel.isEnabled = true
        }
        else
        {
            self.ringDisk1.isEnabled = false
            self.ringDisk2.isEnabled = false
            self.betweenAndLabel.isEnabled = false
        }
        
        if self.customSections.state == .on
        {
            self.numCustomSections.isEnabled = true
        }
        else
        {
            self.numCustomSections.isEnabled = false
        }
    }
    
    @IBAction func handleNumSections(_ sender: Any)
    {
        self.SetControlEnables()
    }
    
    @IBAction func handleBetweenDisks(_ sender: Any)
    {
        self.SetControlEnables()
    }
    
    @IBAction func handleInterleave(_ sender: Any)
    {
        self.SetControlEnables()
    }
    
    @IBAction func handleLineLocation(_ sender: Any)
    {
    }
    
}
