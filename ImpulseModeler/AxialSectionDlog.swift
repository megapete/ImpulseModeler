//
//  AxialSectionDlog.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2016-10-28.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class AxialSectionDlog: NSWindowController {

    var coilReference = 0
    @IBOutlet weak var coilRefField: NSTextField!
    
    var sectionReference = 0
    @IBOutlet weak var sectionRefField: NSTextField!
    
    @IBOutlet weak var totalTurnsField: NSTextField!
    var totalTurns = 0.0
    @IBOutlet weak var totalDisksField: NSTextField!
    var totalDisks = 0.0
    @IBOutlet weak var topDiskCapField: NSTextField!
    var topDiskCap = 0.0
    @IBOutlet weak var commonDiskCapField: NSTextField!
    var commonDiskCap = 0.0
    @IBOutlet weak var bottomDiskCapField: NSTextField!
    var bottomDiskCap = 0.0
    @IBOutlet weak var diskResistanceField: NSTextField!
    var diskResistance = 0.0
    @IBOutlet weak var diskHeightField: NSTextField!
    var diskHeight = 0.0
    @IBOutlet weak var diskRBField: NSTextField!
    var diskRB = 0.0
    @IBOutlet weak var interdiskField: NSTextField!
    var interdisk = 0.0
    @IBOutlet weak var overTopDiskField: NSTextField!
    var overTopDisk = 0.0
    
    @IBOutlet weak var topStaticRingBox: NSButton!
    var hasTopStaticRing = false
    @IBOutlet weak var bottomStaticRingBox: NSButton!
    var hasBottomStaticRing = false
    @IBOutlet weak var interleavedBox: NSButton!
    var isInterleaved = false
    
    override var windowNibName: String!
    {
        return "AxialSectionDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        coilRefField.stringValue = "Coil reference: \(coilReference)"
        sectionRefField.stringValue = "Section reference: \(sectionReference)"
        
        totalTurnsField.doubleValue = totalTurns
        totalDisksField.doubleValue = totalDisks
        topDiskCapField.doubleValue = topDiskCap
        commonDiskCapField.doubleValue = commonDiskCap
        bottomDiskCapField.doubleValue = bottomDiskCap
        diskResistanceField.doubleValue = diskResistance
        diskHeightField.doubleValue = diskHeight
        diskRBField.doubleValue = diskRB
        interdiskField.doubleValue = interdisk
        overTopDiskField.doubleValue = overTopDisk
        
        topStaticRingBox.state = (hasTopStaticRing ? NSOnState : NSOffState)
        bottomStaticRingBox.state = (hasBottomStaticRing ? NSOnState : NSOffState)
        interleavedBox.state = (isInterleaved ? NSOnState : NSOffState)
    }
    
    enum DlogResult {case cancel, done, previous, next}
    func runDialog(_ parentCoil:Int, sectionNum:Int, usingSection:AxialSection?) -> (section:AxialSection, result:DlogResult)
    {
        self.coilReference = parentCoil
        self.sectionReference = sectionNum
        
        if let oldSection = usingSection
        {
            
        }
    }
    
}
