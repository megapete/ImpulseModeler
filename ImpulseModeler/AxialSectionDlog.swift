//
//  AxialSectionDlog.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2016-10-28.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class AxialSectionDlog: NSWindowController {

    var coilReference = ""
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
    
    @IBOutlet var previousButton: NSButton!
    
    var returnedSection:AxialSection? = nil
    var returnValue = DlogResult.cancel
    
    override var windowNibName: NSNib.Name!
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
        
        topStaticRingBox.state = (hasTopStaticRing ? .on : .off)
        bottomStaticRingBox.state = (hasBottomStaticRing ? .on : .off)
        interleavedBox.state = (isInterleaved ? .on : .off)
        
        previousButton.isEnabled = (sectionReference == 0 ? false : true)
    }
    
    enum DlogResult {case cancel, done, previous, next}
    func runDialog(_ parentCoil:Coil, sectionNum:Int, usingSection:AxialSection?) -> (section:AxialSection?, result:DlogResult)
    {
        // Note: We pass the parent coil for its name, but also for the future possibility of calculating the capacitances between disks
        
        self.coilReference = parentCoil.coilName
        self.sectionReference = sectionNum
        
        if let oldSection = usingSection
        {
            self.totalTurns = oldSection.turns
            self.totalDisks = oldSection.numDisks
            self.topDiskCap = oldSection.topDiskSerialCapacitance
            self.commonDiskCap = oldSection.commonDiskSerialCapacitance
            self.bottomDiskCap = oldSection.bottomDiskSerialCapacitance
            self.diskResistance = oldSection.diskResistance
            self.diskHeight = Double(oldSection.diskSize.height)
            self.diskRB = Double(oldSection.diskSize.width)
            self.interdisk = oldSection.interDiskDimn
            self.overTopDisk = oldSection.overTopDiskDimn
            self.hasTopStaticRing = oldSection.topStaticRing
            self.hasBottomStaticRing = oldSection.bottomStaticRing
            self.isInterleaved = oldSection.isInterleaved
        }
        
        NSApp.runModal(for: self.window!)
        
        return (self.returnedSection, self.returnValue)
    }
    
    func saveSectionAndClose()
    {
        let diskSize:NSSize = NSSize(width: self.diskRBField.doubleValue, height: self.diskHeightField.doubleValue)
        
        self.returnedSection = AxialSection(sectionAxialPosition: self.sectionReference, turns: self.totalTurnsField.doubleValue, numDisks: self.totalDisksField.doubleValue, topDiskSerialCapacitance: self.topDiskCapField.doubleValue, bottomDiskSerialCapacitance: self.bottomDiskCapField.doubleValue, commonDiskSerialCapacitance: self.commonDiskCapField.doubleValue, topStaticRing: self.topStaticRingBox.state == .on, bottomStaticRing: self.bottomStaticRingBox.state == .off, isInterleaved: self.interleavedBox.state == .on, diskResistance: self.diskResistanceField.doubleValue, diskSize: diskSize, interDiskDimn: self.interdiskField.doubleValue, overTopDiskDimn: self.overTopDiskField.doubleValue, phaseNum:1)
        
        NSApp.stopModal()
        self.window!.orderOut(self)
    }

    @IBAction func doneButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.done
        saveSectionAndClose()
    }
    
    @IBAction func nextButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.next
        saveSectionAndClose()
    }
    
    @IBAction func previousButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.previous
        saveSectionAndClose()
    }
    
    @IBAction func cancelButtonPushed(_ sender: AnyObject)
    {
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    
}
