//
//  AppController.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class AppController: NSObject {

    // The physical and capacitance data for one phase of the transformer
    var phaseDefinition:Phase?
    
    // The special "Ground" section used in the model
    let gndSection = PCH_DiskSection(coilRef: -1, diskRect: NSMakeRect(0, 0, 0, 0), N: 0, J: 0, windHt: 0, coreRadius: 0, secData: PCH_SectionData(sectionID: "GND", serNum: -1, inNode:-1, outNode:-1))
    
    @IBOutlet weak var inchItem: NSMenuItem!
    @IBOutlet weak var metricItem: NSMenuItem!
    var unitFactor = 25.4 / 1000.0
    
    // The model in the format required by the routine for making a spice ".cir" file
    var theModel:[PCH_DiskSection]?
    
    func totalSectionsInPhase(_ phase:Phase) -> Int
    {
        var result = 0
        
        for nextCoil in phase.coils
        {
            result += Int(round(nextCoil.numDisks))
        }
        
        return result
    }
    
    // Menu Handlers
    
    @IBAction func handleCreateModel(_ sender: AnyObject)
    {
        guard let phase = self.phaseDefinition
        else
        {
            return
        }
        
        if (theModel != nil)
        {
            // TODO: Give the user a chance to save the model
            DLog("Note: This will destroy the existing model")
        }
        
        theModel = Array()
        
        // we reserve some capacity in an attempt to help performance
        theModel!.reserveCapacity(totalSectionsInPhase(phase))
        
        // This is used for the in/out nodes in PCH_SectionData but doesn't do anything yet
        var nodeSerialNumber = 0
        var sectionSerialNumber = 0
        
        for nextCoil in phase.coils
        {
            DLog("Creating model for coil: \(nextCoil.coilName)")
            // create and save the basic disk data for each disk in the coil
            
            guard let axialSections = nextCoil.sections
            else
            {
                // fatal error
                ALog("Coil has no sections!")
                return
            }
            
            var zCurrent = nextCoil.CoilBottom(phase.core.height * unitFactor, centerOffset: phase.core.coilCenterOffset * unitFactor)
            let coilID = nextCoil.coilName
            
            DLog("Creating disks")
            for nextAxialSection in axialSections
            {
                for currentSection in 0..<Int(nextAxialSection.numDisks)
                {
                    let diskRect = NSRect(x: nextCoil.innerRadius * unitFactor, y: zCurrent, width: Double(nextAxialSection.diskSize.width) * unitFactor, height: Double(nextAxialSection.diskSize.height) * unitFactor)
                    
                    let diskArea = Double(nextAxialSection.diskSize.width * nextAxialSection.diskSize.height) * unitFactor * unitFactor
                    
                    var sectionData = PCH_SectionData(sectionID: String(format: "%@%03d", coilID, currentSection+1), serNum: sectionSerialNumber, inNode: nodeSerialNumber, outNode: nodeSerialNumber + 1)
                    
                    let seriesCap = (currentSection == 0 ? nextAxialSection.bottomDiskSerialCapacitance : (currentSection == Int(nextAxialSection.numDisks) - 1) ? nextAxialSection.topDiskSerialCapacitance : nextAxialSection.commonDiskSerialCapacitance)
                    
                    sectionData.seriesCapacitance = seriesCap
                    
                    let diskResistance = nextAxialSection.diskResistance
                    
                    sectionData.resistance = diskResistance
                    
                    let theNewSection = PCH_DiskSection(coilRef: nextCoil.coilRadialPosition, diskRect: diskRect, N: nextAxialSection.turns / nextAxialSection.numDisks, J: nextCoil.amps / diskArea, windHt: phase.core.height * unitFactor, coreRadius: phase.core.diameter * unitFactor / 2.0, secData: sectionData)
                    
                    theNewSection.data.selfInductance = theNewSection.SelfInductance()
                    
                    theModel!.append(theNewSection)
                    
                    sectionSerialNumber += 1
                    nodeSerialNumber += 1
                    
                    zCurrent += (Double(nextAxialSection.diskSize.height) + nextAxialSection.interDiskDimn) * unitFactor
                }
                
                zCurrent += (nextAxialSection.overTopDiskDimn - nextAxialSection.interDiskDimn) * unitFactor
            }
            
            DLog("Done creating disks.")
            
            nodeSerialNumber += 1
        }
        
        // Shunt capacitances are either to ground or to the previous coil. The first coil has capacitance to the core, which is always to ground. We go through the coil array once more now that all of the sections have been created (this could possibly be made somewhat more efficient by doing it in the previous loop).
        
        DLog("Calculating shunt capacitances")
        // Define some variables for the loop for defining intercoil capacitances
        var previousStartIndex = 0
        
        var currentStartIndex = 0
        for theCoilNum in 0..<phase.coils.count
        {
            let theCoil = phase.coils[theCoilNum]
            
            let currentEndIndex = currentStartIndex + Int(round(theCoil.numDisks)) - 1
            
            // We start by defining the capacitances to ground (if any) for this coil
            var coilCapacitanceToGround = theCoil.capacitanceToGround
            
            // The innermost coil's "capacitance to previous coil" is actually to the core, so add that to the ground capacitance
            if (theCoilNum == 0)
            {
                coilCapacitanceToGround += theCoil.capacitanceToPreviousCoil
            }
            
            // We only run through this loop if the ground capacitance is non-zero
            if coilCapacitanceToGround != 0.0
            {
                for sectionIndex in currentStartIndex...currentEndIndex
                {
                    let currentSection = self.theModel![sectionIndex]
                    
                    let diskCapToGnd = coilCapacitanceToGround / round(theCoil.numDisks)
                    
                    currentSection.data.shuntCaps[gndSection] = diskCapToGnd
                    
                }
            }
            
            // we only go through the next loop if this isn't the first coil AND the capacitance to previous coil is non-zero
            if (theCoilNum > 0) && (theCoil.capacitanceToPreviousCoil != 0)
            {
                // let previousEndIndex = currentStartIndex - 1
                
                let maxSections = round(max(phase.coils[theCoilNum].numDisks, phase.coils[theCoilNum-1].numDisks))
                
                let capPerSection = theCoil.capacitanceToPreviousCoil / maxSections
                
                var leftSectionIndex = previousStartIndex
                var rightSectionIndex = currentStartIndex
                
                for j in 0..<Int(maxSections)
                {
                    theModel![leftSectionIndex].data.shuntCaps[theModel![rightSectionIndex]] = capPerSection
                    theModel![rightSectionIndex].data.shuntCaps[theModel![leftSectionIndex]] = capPerSection

                    leftSectionIndex = previousStartIndex + Int(Double(j+1) * (round(phase.coils[theCoilNum-1].numDisks) / maxSections))
                    rightSectionIndex = currentStartIndex + Int(Double(j+1) * (round(phase.coils[theCoilNum].numDisks) / maxSections))
                }
            }
            
            previousStartIndex = currentStartIndex
            
            currentStartIndex = currentEndIndex + 1
        }
        DLog("Done!")
        
        // And now we calculate the mutual inductances
        var diskArray = theModel!
        
        DLog("Calculating mutual inductances")
        while diskArray.count > 0
        {
            let nDisk = diskArray.remove(at: 0)
            
            DLog("Checking \(nDisk.data.sectionID)")
            
            for otherDisk in diskArray
            {
                let mutInd = fabs(nDisk.MutualInductanceTo(otherDisk))
                
                let mutIndCoeff = mutInd / sqrt(nDisk.data.selfInductance * otherDisk.data.selfInductance)
                if (mutIndCoeff < 0.0 || mutIndCoeff > 1.0)
                {
                    DLog("Illegal Mutual Inductance:\(mutInd); this.SelfInd:\(nDisk.data.selfInductance); that.SelfInd:\(otherDisk.data.selfInductance)")
                }
                
                nDisk.data.mutualInductances[otherDisk.data.sectionID] = mutInd
                otherDisk.data.mutualInductances[nDisk.data.sectionID] = mutInd
                
                // This ends up being the important thing to do
                nDisk.data.mutInd[otherDisk] = mutInd
                otherDisk.data.mutInd[nDisk] = mutInd
                
                nDisk.data.mutIndCoeff[otherDisk.data.sectionID] = mutIndCoeff
                otherDisk.data.mutIndCoeff[nDisk.data.sectionID] = mutIndCoeff
                
            }
        }
        
        DLog("Done!")
    }
    
    @IBAction func handleUnitsMenu(_ sender: AnyObject)
    {
        let wMenu:NSMenuItem = sender as! NSMenuItem
        
        if wMenu == self.inchItem
        {
            self.inchItem.state = NSOnState
            self.metricItem.state = NSOffState
            self.unitFactor = 25.4 / 1000.0
        }
        else if wMenu == self.metricItem
        {
            self.inchItem.state = NSOffState
            self.metricItem.state = NSOnState
            self.unitFactor = 1.0 / 1000.0
        }
    }
    
    
    @IBAction func handleNew(_ sender: AnyObject)
    {
        DLog("Handling New menu command")
        
        let oldPhase = self.phaseDefinition
        
        if (oldPhase != nil)
        {
            // TODO: Ask user if he wants to save the current phase before deleteing it
            DLog("Deleting existing phase")
            self.phaseDefinition = nil
        }
        
        // Bring up the core dialog
        let coreDlog = CoreInputDlog()
        guard let newCore = coreDlog.runDialog(nil)
        else
        {
            DLog("User did not define a core")
            self.phaseDefinition = oldPhase
            return
        }
        
        var doneCoils = false
        var currentCoilRefNum = 0
        
        var coils:[Coil]? = nil
        
        while !doneCoils
        {
            var coilExists = false
            var coil:Coil? = nil
            
            if let existingCoils = coils
            {
                if existingCoils.count > currentCoilRefNum
                {
                    coilExists = true
                    coil = existingCoils[currentCoilRefNum]
                }
            }
            else
            {
                coils = Array()
            }
            
            let coilDlog = CoilDlog()
            let newCoils = coilDlog.runDialog(currentCoilRefNum, usingCoil: coil)
            
            if (newCoils.result == CoilDlog.DlogResult.cancel)
            {
                doneCoils = true
                DLog("User did not define a coil")
                self.phaseDefinition = oldPhase
                return
            }
            else
            {
                if (coilExists)
                {
                    coils![currentCoilRefNum] = newCoils.coil!
                }
                else
                {
                    coils!.append(newCoils.coil!)
                }
                
                if (newCoils.result == CoilDlog.DlogResult.done)
                {
                    doneCoils = true
                }
                else if (newCoils.result == CoilDlog.DlogResult.previous)
                {
                    currentCoilRefNum -= 1
                }
                else // must be next
                {
                    currentCoilRefNum += 1
                }
                
            }
        }
        
        self.phaseDefinition = Phase(core: newCore, coils: coils!)
    }
}
