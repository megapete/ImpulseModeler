//
//  CoilDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-28.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class CoilDlog: NSWindowController {

    
    @IBOutlet var coilNameField: NSTextField!
    var coilName = ""
    @IBOutlet var radialPositionField: NSTextField!
    var radialPosition = 0
    @IBOutlet var ampsField: NSTextField!
    var amps = 0.0
    @IBOutlet var radialCapacitanceField: NSTextField!
    var radialCapacitance = 0.0
    @IBOutlet var innerDiameterField: NSTextField!
    var innerDiameter = 0.0
    @IBOutlet weak var capacitanceToGroundField: NSTextField!
    var capToGround = 0.0
    @IBOutlet var eddyLossField: NSTextField!
    var eddyLossPercentage = 0.0
    
    @IBOutlet var negativeCurrentButton: NSButton!
    @IBOutlet var noCurrentButton: NSButton!
    @IBOutlet var positiveCurrentButton: NSButton!
    var currentDirection = 1
    
    @IBOutlet var prevButton: NSButton!
    
    enum DlogResult {case cancel, done, previous, next}
    var returnValue:DlogResult = DlogResult.cancel
    var returnedCoil:Coil? = nil
    
    var sections:[AxialSection]?
    
    override var windowNibName: String!
    {
        return "CoilDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        coilNameField.stringValue = coilName
        radialPositionField.integerValue = radialPosition
        ampsField.doubleValue = amps
        radialCapacitanceField.doubleValue = radialCapacitance
        innerDiameterField.doubleValue = innerDiameter
        capacitanceToGroundField.doubleValue = capToGround
        eddyLossField.doubleValue = eddyLossPercentage
        
        if currentDirection > 0
        {
            positiveCurrentButton.state = NSOnState
        }
        else if currentDirection < 0
        {
            negativeCurrentButton.state = NSOnState
        }
        else
        {
            noCurrentButton.state = NSOnState
        }
        
        prevButton.isEnabled = (radialPosition != 0)
    }
    
    func runDialog(_ coilPos:Int, usingCoil:Coil?) -> (coil:Coil?, result:DlogResult)
    {
        if let oldCoil = usingCoil
        {
            self.coilName = oldCoil.coilName
            self.radialPosition = oldCoil.coilRadialPosition
            self.amps = oldCoil.amps
            self.radialCapacitance = oldCoil.capacitanceToPreviousCoil
            self.innerDiameter = oldCoil.innerRadius * 2.0
            self.currentDirection = oldCoil.currentDirection
            self.capToGround = oldCoil.capacitanceToGround
            self.sections = oldCoil.sections
            self.eddyLossPercentage = oldCoil.eddyLossPercentage
        }
        else
        {
            self.radialPosition = coilPos
        }
        
        NSApp.runModal(for: self.window!)
        
        return (self.returnedCoil, self.returnValue)
    }
    
    
    @IBAction func defineSectionsButtonPushed(_ sender: AnyObject)
    {
        var doneSections = false
        
        let currentCoil = Coil(coilName: coilNameField.stringValue, coilRadialPosition: radialPositionField.integerValue, amps: ampsField.doubleValue, currentDirection: (positiveCurrentButton.state == NSOnState ? 1 : (negativeCurrentButton.state == NSOnState ? -1 : 0)), capacitanceToPreviousCoil: radialCapacitanceField.doubleValue, capacitanceToGround:capacitanceToGroundField.doubleValue, innerRadius: innerDiameterField.doubleValue / 2.0, eddyLossPercentage:eddyLossField.doubleValue, sections: sections)
        
        var currentSectionReferenceNumber = 0
        
        while (!doneSections)
        {
            var sectionExists = false
            var section:AxialSection? = nil
            
            if let existingSections = self.sections
            {
                if existingSections.count > currentSectionReferenceNumber
                {
                    sectionExists = true
                    section = existingSections[currentSectionReferenceNumber]
                }
            }
            else
            {
                self.sections = Array()
            }
            
            let axialDlog = AxialSectionDlog()
            let runResult = axialDlog.runDialog(currentCoil, sectionNum: currentSectionReferenceNumber, usingSection: section)
            
            if (runResult.result == AxialSectionDlog.DlogResult.cancel)
            {
                doneSections = true
            }
            else
            {
                if (sectionExists)
                {
                    self.sections![currentSectionReferenceNumber] = runResult.section!
                }
                else
                {
                    self.sections!.append(runResult.section!)
                }
                
                if (runResult.result == AxialSectionDlog.DlogResult.done)
                {
                    doneSections = true
                }
                else if (runResult.result == AxialSectionDlog.DlogResult.previous)
                {
                    currentSectionReferenceNumber -= 1
                }
                else // must be next
                {
                    currentSectionReferenceNumber += 1
                }
            }
            
        }
    }
    
    func saveCoilAndClose()
    {
        returnedCoil = Coil(coilName: coilNameField.stringValue, coilRadialPosition: radialPositionField.integerValue, amps: ampsField.doubleValue, currentDirection: (positiveCurrentButton.state == NSOnState ? 1 : (negativeCurrentButton.state == NSOnState ? -1 : 0)), capacitanceToPreviousCoil: radialCapacitanceField.doubleValue, capacitanceToGround:capacitanceToGroundField.doubleValue, innerRadius: innerDiameterField.doubleValue / 2.0, eddyLossPercentage:eddyLossField.doubleValue, sections: self.sections)
        
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func handleCurrDirGroup(_ sender: NSButton)
    {
        let wButton = sender
        
        if wButton == noCurrentButton
        {
            positiveCurrentButton.state = NSOffState
            negativeCurrentButton.state = NSOffState
        }
        else if wButton == positiveCurrentButton
        {
            negativeCurrentButton.state = NSOffState
            noCurrentButton.state = NSOffState
        }
        else if wButton == negativeCurrentButton
        {
            positiveCurrentButton.state = NSOffState
            noCurrentButton.state = NSOffState
        }
        
        wButton.state = NSOnState
    }
    
    
    @IBAction func doneButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.done
        saveCoilAndClose()
    }
    
    @IBAction func nextButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.next
        saveCoilAndClose()
    }
    
    @IBAction func previousButtonPushed(_ sender: AnyObject)
    {
        self.returnValue = DlogResult.previous
        saveCoilAndClose()
    }
    
    @IBAction func cancelButtonPushed(_ sender: AnyObject)
    {
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
}
