//
//  AppController.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

// A helper class to allow saving to and restoring from files
class PhaseModel:NSObject, NSCoding
{
    let phase:Phase
    let model:[PCH_DiskSection]
    
    init(phase:Phase, model:[PCH_DiskSection])
    {
        self.phase = phase
        // let gndSectionArray = [AppController.gndSection]
        self.model = model // + gndSectionArray
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        
        let phase = aDecoder.decodeObject(forKey: "Phase") as! Phase
        let model = aDecoder.decodeObject(forKey: "Model") as! [PCH_DiskSection]
        
        self.init(phase:phase, model:model)
    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.phase, forKey: "Phase")
        aCoder.encode(self.model, forKey: "Model")
    }
}

// This utility function is used to get the PCH_DiskSection that corresponds to the given sectionID (String)
func DiskSectionUsingID(_ sectID:String, inModel:[PCH_DiskSection]) -> PCH_DiskSection?
{
    var result:PCH_DiskSection? = nil
    
    if sectID == "GND"
    {
        result = AppController.gndSection
    }
    else
    {
        for nextSection in inModel
        {
            if nextSection.data.sectionID == sectID
            {
                result = nextSection
                break
            }
        }
    }
    
    return result
}

class AppController: NSObject {

    // The physical and capacitance data for one phase of the transformer
    var phaseDefinition:Phase?
    
    // An array of resistance factors, each one to be used for its respective disk. Eventually, the idea will be to calculate the resistance factor for each disk by running the simulation once withe some initial factor, do a Fourier analysis on the current through each resistance, then recalculate the eddy-loss contribution using the results of the analysis.
    var eddyLossFactors:[Double]?
    
    // The Bluebook talks about multiplying the DC resistance by "around 3000" to reflect the higher effective resistance at high frequencies of the eddy loss. I have (for now) decided to use an assumed "equivalent" frequency of 10kHz, which yields a factor of (10000/50)^2 = 40000x the eddy loss component of the resistance at 60Hz.
    let initialEddyLossFactor = 40000.0
    
    // The special "Ground" section used in the model. By convention, its coilRef, serNum, inNode, and outNode are equal to "-1". It's sectionID is "GND".
    static let gndSection = PCH_DiskSection(coilRef: -1, diskRect: NSMakeRect(0, 0, 0, 0), N: 0, J: 0, windHt: 0, coreRadius: 0, secData: PCH_SectionData(sectionID: "GND", serNum: -1, inNode:-1, outNode:-1))
    
    @IBOutlet weak var inchItem: NSMenuItem!
    @IBOutlet weak var metricItem: NSMenuItem!
    var unitFactor = 25.4 / 1000.0
    
    @IBOutlet weak var createModelMenuItem: NSMenuItem!
    @IBOutlet weak var saveCirFileMenuItem: NSMenuItem!
    @IBOutlet weak var runSimMenuItem: NSMenuItem!
    @IBOutlet weak var saveModelMenuItem: NSMenuItem!
    @IBOutlet weak var modifyModelMenuItem: NSMenuItem!

    
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
    
    @IBAction func handleOpenModel(_ sender: AnyObject)
    {
        if (self.theModel != nil)
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlertStyle.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSAlertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
        }
        
        let openFilePanel = NSOpenPanel()
        
        openFilePanel.title = "Open Model"
        openFilePanel.message = "Select the model to open"
        openFilePanel.allowedFileTypes = ["impmdl"]
        openFilePanel.allowsOtherFileTypes = false
        
        if (openFilePanel.runModal() == NSFileHandlingPanelOKButton)
        {
            let archive = NSKeyedUnarchiver.unarchiveObject(withFile: openFilePanel.url!.path) as! PhaseModel
            
            self.theModel = archive.model
            self.phaseDefinition = archive.phase
            
        }
    }
    
    @IBAction func handleSaveModel(_ sender: AnyObject)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Model"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["impmdl"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal() == NSFileHandlingPanelOKButton)
        {
            guard let newFileURL = saveFilePanel.url
                else
            {
                DLog("Bad file name")
                return
            }
            
            let archive = PhaseModel(phase: self.phaseDefinition!, model: self.theModel!)
            
            let archiveResult = NSKeyedArchiver.archiveRootObject(archive, toFile: newFileURL.path)
            
            if (!archiveResult)
            {
                DLog("Couldn't write the file!")
            }
            
            DLog("Finished writing file")
        }
    }
    
    
    @IBAction func handleRunSimulation(_ sender: AnyObject)
    {
        let srcDlog = SourceDefinitionDlog()
        guard let testSource = srcDlog.runDialog()
        else
        {
            DLog("User chose cancel")
            return
        }
        
        let bbModel = PCH_BlueBookModel(theModel: self.theModel!, phase: self.phaseDefinition!)
        
        let connDlog = ConnectionDlog()
        guard let testConnection = connDlog.runDialog(theModel: self.theModel!)
        else
        {
            DLog("User chose cancel")
            return
        }
        
        // Hardcoded connections, this will obviously need to be made more fancy
        let theConnections = [(0, [-1, 20, 42]), (21, [62])]
        
        let simTimeStep = 10.0E-9
        let saveTimeStep = 100.0E-9
        let totalSimTime = 100.0E-6
        
        guard let resultMatrices = bbModel.SimulateWithConnections(theConnections, sourceConnection: (testSource, 41), simTimeStep: simTimeStep, saveTimeStep: saveTimeStep, totalTime: totalSimTime)
        else
        {
            DLog("Simulation failed!")
            return
        }
        
        // Set up the array for the simulation times
        let numTimeSteps = Int(totalSimTime / saveTimeStep) + 1
        var timeArray = Array(repeating: 0.0, count: numTimeSteps)
        var nextTime = 0.0
        for i in 0..<numTimeSteps
        {
            timeArray[i] = nextTime
            nextTime += saveTimeStep
        }
        
        // Set up the arrays for the node and section names
        let sectionCount = theModel!.count
        let nodeCount = sectionCount + self.phaseDefinition!.coils.count
        var nodeNames = Array(repeating: "", count: nodeCount)
        var deviceNames = Array(repeating: "", count: sectionCount)
        var currentNodeIndex = 0
        var currentDeviceIndex = 0
        var lastCoilName = self.phaseDefinition!.coils[0].coilName
        var lastDiskNum = ""
        
        for nextSection in self.theModel!
        {
            let nextSectionID = nextSection.data.sectionID
            deviceNames[currentDeviceIndex] = nextSectionID
            currentDeviceIndex += 1
            
            let coilName = PCH_StrLeft(nextSectionID, length: 2)
            if (coilName != lastCoilName)
            {
                nodeNames[currentNodeIndex] = lastCoilName + "I" + lastDiskNum
                currentNodeIndex += 1
            }
            
            let diskNum = PCH_StrRight(nextSectionID, length: 3)
            nodeNames[currentNodeIndex] = coilName + "I" + diskNum
            currentNodeIndex += 1
            lastCoilName = coilName
            lastDiskNum = "\(Int(diskNum)! + 1)"
        }
        
        // Add the name of the last disk
        nodeNames[currentNodeIndex] = lastCoilName + "I" + lastDiskNum
        
        
        let bbModelOutput = PCH_BlueBookModelOutput(timeArray: timeArray, voltageNodes: nodeNames, voltsMatrix: resultMatrices.V, deviceIDs: deviceNames, ampsMatrix: resultMatrices.I)
        
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Impulse Simulation Results"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["impres"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal() == NSFileHandlingPanelOKButton)
        {
            guard let newFileURL = saveFilePanel.url
                else
            {
                DLog("Bad file name")
                return
            }
            
            NSKeyedArchiver.setClassName("ImpulseResult", for: PCH_BlueBookModelOutput.self)
            let archiveResult = NSKeyedArchiver.archiveRootObject(bbModelOutput, toFile: newFileURL.path)
            
            if (!archiveResult)
            {
                DLog("Couldn't write the file!")
            }
            
            DLog("Finished writing file")
        }
    }
    
    @IBAction func handleModifyModel(_ sender: Any)
    {
        let oldPhase = self.phaseDefinition!
        
        // Bring up the core dialog
        let coreDlog = CoreInputDlog()
        
        var newCore = coreDlog.runDialog(oldPhase.core)
        if newCore == nil
        {
            newCore = oldPhase.core
        }
        
        var doneCoils = false
        var currentCoilRefNum = 0
        
        var coils:[Coil]? = oldPhase.coils
        
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
                DLog("User chose cancel")
                self.phaseDefinition = Phase(core: newCore!, coils: oldPhase.coils)
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
        
        self.phaseDefinition = Phase(core: newCore!, coils: coils!)
        
        self.handleCreateModel(self)
    }
    
    
    @IBAction func handleCreateModel(_ sender: AnyObject)
    {
        guard let phase = self.phaseDefinition
        else
        {
            return
        }
        
        if (theModel != nil)
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlertStyle.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSAlertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
            
            DLog("Note: This will destroy the existing model")
        }
        
        theModel = Array()
        
        // we reserve some capacity in an attempt to help performance
        theModel!.reserveCapacity(totalSectionsInPhase(phase))
        
        // Initialize the eddy-loss factors for the sections
        eddyLossFactors = Array(repeating: initialEddyLossFactor, count: totalSectionsInPhase(phase))
        
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
                // The coil has no sections (probably the user pressed "Next" when he did not mean to actually add another coil
                DLog("Coil has no sections!")
                continue
            }
            
            var zCurrent = nextCoil.CoilBottom(phase.core.height, centerOffset: phase.core.coilCenterOffset) * unitFactor
            let coilID = nextCoil.coilName
            
            DLog("Creating disks")
            
            let coilAvgEddyLossPercentage = nextCoil.eddyLossPercentage
            
            var sectionNumberOffset = 0
            for nextAxialSection in axialSections
            {
                // This will work even if the user accidentally pressed "Next" when he didn't want to add another section, as long as he didn't enter a non-zero value for "number of disks" (the dolt).
                for currentSection in 0..<Int(nextAxialSection.numDisks)
                {
                    let diskRect = NSRect(x: nextCoil.innerRadius * unitFactor, y: zCurrent, width: Double(nextAxialSection.diskSize.width) * unitFactor, height: Double(nextAxialSection.diskSize.height) * unitFactor)
                    
                    let diskArea = Double(nextAxialSection.diskSize.width * nextAxialSection.diskSize.height) * unitFactor * unitFactor
                    
                    let sectionData = PCH_SectionData(sectionID: String(format: "%@%03d", coilID, sectionNumberOffset + currentSection + 1), serNum: sectionSerialNumber, inNode: nodeSerialNumber, outNode: nodeSerialNumber + 1)
                    
                    let seriesCap = (currentSection == 0 ? nextAxialSection.bottomDiskSerialCapacitance : (currentSection == Int(nextAxialSection.numDisks) - 1) ? nextAxialSection.topDiskSerialCapacitance : nextAxialSection.commonDiskSerialCapacitance)
                    
                    sectionData.seriesCapacitance = seriesCap
                    
                    let currentDiskEddyMultiplier = eddyLossFactors![sectionSerialNumber]
                    let diskResistance = nextAxialSection.diskResistance * (1 + coilAvgEddyLossPercentage * currentDiskEddyMultiplier / 100.0)
                    
                    sectionData.resistance = diskResistance
                    
                    let turnsPerDisk = nextAxialSection.turns / nextAxialSection.numDisks
                    let theNewSection = PCH_DiskSection(coilRef: nextCoil.coilRadialPosition, diskRect: diskRect, N: turnsPerDisk, J: turnsPerDisk * nextCoil.amps / diskArea, windHt: phase.core.height * unitFactor, coreRadius: phase.core.diameter * unitFactor / 2.0, secData: sectionData)
                    
                    theNewSection.data.selfInductance = theNewSection.SelfInductance(phase.core.htFactor)
                    
                    theModel!.append(theNewSection)
                    
                    sectionSerialNumber += 1
                    nodeSerialNumber += 1
                    
                    zCurrent += (Double(nextAxialSection.diskSize.height) + nextAxialSection.interDiskDimn) * unitFactor
                }
                
                // we increment the node serial number after each axial section, which allows us to connect center-connected taps, etc.
                nodeSerialNumber += 1
                
                sectionNumberOffset += Int(nextAxialSection.numDisks)
                zCurrent += (nextAxialSection.overTopDiskDimn - nextAxialSection.interDiskDimn) * unitFactor
            }
            
            DLog("Done creating disks.")
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
                    
                    currentSection.data.shuntCapacitances[AppController.gndSection.data.sectionID] = diskCapToGnd
                    // currentSection.data.shuntCaps[AppController.gndSection] = diskCapToGnd
                    
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
                    theModel![leftSectionIndex].data.shuntCapacitances[theModel![rightSectionIndex].data.sectionID] = capPerSection
                    theModel![rightSectionIndex].data.shuntCapacitances[theModel![leftSectionIndex].data.sectionID] = capPerSection
                    
                    // theModel![leftSectionIndex].data.shuntCaps[theModel![rightSectionIndex]] = capPerSection
                    // theModel![rightSectionIndex].data.shuntCaps[theModel![leftSectionIndex]] = capPerSection

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
            
            DLog("Calculating to: \(nDisk.data.sectionID)")
            
            for otherDisk in diskArray
            {
                let mutInd = fabs(nDisk.MutualInductanceTo(otherDisk, windHtFactor:phase.core.htFactor))
                
                let mutIndCoeff = mutInd / sqrt(nDisk.data.selfInductance * otherDisk.data.selfInductance)
                if (mutIndCoeff < 0.0 || mutIndCoeff > 1.0)
                {
                    DLog("Illegal Mutual Inductance:\(mutInd); this.SelfInd:\(nDisk.data.selfInductance); that.SelfInd:\(otherDisk.data.selfInductance)")
                }
                
                nDisk.data.mutualInductances[otherDisk.data.sectionID] = mutInd
                otherDisk.data.mutualInductances[nDisk.data.sectionID] = mutInd
                
                // This ends up being the important thing to do
                // nDisk.data.mutInd[otherDisk] = mutInd
                // otherDisk.data.mutInd[nDisk] = mutInd
                
                nDisk.data.mutIndCoeff[otherDisk.data.sectionID] = mutIndCoeff
                otherDisk.data.mutIndCoeff[nDisk.data.sectionID] = mutIndCoeff
                
            }
        }
        
        DLog("Done!")
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
    {
        if (menuItem == self.createModelMenuItem)
        {
            return self.phaseDefinition != nil && self.theModel == nil
        }
        
        if (menuItem == self.saveCirFileMenuItem) || (menuItem == self.runSimMenuItem) || (menuItem == self.saveModelMenuItem) || (menuItem == self.modifyModelMenuItem)
        {
            return self.theModel != nil
        }
        
        return true
    }
    
    
    
    @IBAction func handleCreateCirFile(_ sender: AnyObject)
    {
        var fString = "Description goes here\n"
        var mutSerNum = 1
        var dSections = [String]()
        
        let diskArray = self.theModel!
        let coilArray = self.phaseDefinition!.coils
        
        for nextDisk in diskArray
        {
            // Separate the disk ID into the coil name and the disk number
            let nextSectionID = nextDisk.data.sectionID
            dSections.append(nextSectionID)
            
            let coilName = PCH_StrLeft(nextSectionID, length: 2)
            
            let diskNum = PCH_StrRight(nextSectionID, length: 3)
            
            let nextDiskNum = String(format: "%03d", Int(diskNum)! + 1)
            
            let inNode = coilName + "I" + diskNum
            let outNode = coilName + "I" + nextDiskNum
            let midNode = coilName + "M" + diskNum
            let resName = "R" + nextSectionID
            let selfIndName = "L" + nextSectionID
            let indParResName = "RPL" + nextSectionID
            let seriesCapName = "CS" + nextSectionID
            
            fString += String(format: "* Definitions for section: %@\n", nextSectionID)
            fString += selfIndName + " " + inNode + " " + midNode + String(format: " %.4E\n", nextDisk.data.selfInductance)
            // Calculate the resistance that we need to put in parallel with the inductance to reducing ringing (according to ATPDraw: ind * 2.0 * 7.5 * 1000.0 / 1E9). Note that the model still rings in LTSpice, regardless of how low I set this value.
            fString += indParResName + " " + inNode + " " + midNode + String(format: " %.4E\n", nextDisk.data.selfInductance * 2.0 * 7.5 * 1000.0 / 1.0E-9)
            
            fString += resName + " " + midNode + " " + outNode + String(format: " %.4E\n", nextDisk.data.resistance)
            fString += seriesCapName + " " + inNode + " " + outNode + String(format: " %.4E\n", nextDisk.data.seriesCapacitance)
            
            var shuntCapSerialNum = 1
            for nextShuntCap in nextDisk.data.shuntCapacitances
            {
                
                guard let nextShuntSection = DiskSectionUsingID(nextShuntCap.key, inModel: self.theModel!)
                else
                {
                    continue
                }
                
                // We ignore inner coils because they've already been done (note that we need to consider the core, though)
                if ((nextShuntSection.coilRef < nextDisk.coilRef) && (nextShuntSection.coilRef != -1))
                {
                    continue
                }
                
                let nsName = String(format: "CP%@%03d", nextSectionID, shuntCapSerialNum)
                
                /*
                 let shuntID = nextShuntCap.0
                 
                 // make sure that this capacitance is not already done
                 if dSections.contains(shuntID)
                 {
                 continue
                 }
                 */
                
                var shuntNode = String()
                if (nextShuntSection.coilRef == -1)
                {
                    shuntNode = "0"
                }
                else
                {
                    shuntNode = coilArray[nextShuntSection.coilRef].coilName
                    shuntNode += "I"
                    let nodeNum = PCH_StrRight(nextShuntCap.key, length: 3)
                    shuntNode += nodeNum
                }
                
                fString += nsName + " " + inNode + " " + shuntNode + String(format: " %.4E\n", nextShuntCap.value)
                
                shuntCapSerialNum += 1
            }
            
            for nextMutualInd in nextDisk.data.mutIndCoeff
            {
                let miName = String(format: "K%05d", mutSerNum)
                
                let miID = nextMutualInd.0
                
                if (dSections.contains(miID))
                {
                    continue
                }
                
                fString += miName + " " + selfIndName + " L" + miID + String(format: " %.4E\n", nextMutualInd.1)
                
                mutSerNum += 1
            }
        }
        
        // We connect the coil ends and centers to their nodes using very small resistances
        fString += "\n* Coil ends and centers\n"
        
        
        for i in 0..<coilArray.count
        {
            let nextID = coilArray[i].coilName
            
            fString += "R" + nextID + "BOT " + nextID + "BOT " + nextID + "I001 1.0E-9\n"
            fString += "R" + nextID + "CEN " + nextID + "CEN " + nextID + String(format: "I%03d 1.0E-9\n", Int(round(coilArray[i].numDisks)) / 2 + 1)
            fString += "R" + nextID + "TOP " + nextID + "TOP " + nextID + String(format: "I%03d 1.0E-9\n", Int(round(coilArray[i].numDisks)) + 1)
        }
        
        
        // TODO: Add code for the connection that interests us
        fString += "\n* Connections\n\n"
        
        // The shot
        fString += "* Impulse shot\nVBIL HVTOP 0 EXP(0 128.75k 0 2.2E-7 1.0E-6 7.0E-5)\n\n"
        
        // Options required to make this work most of the time
        fString += "* options for LTSpice\n.OPTIONS reltol=0.02 trtol=7 abstol=1e-6 vntol=1e-4 method=gear\n\n"
        
        fString += ".TRAN 1.0ns 100us\n\n.END"
        
        self.saveFileWithString(fString)
    }
    
    func saveFileWithString(_ fileString:String)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Spice data"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["cir"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal() == NSFileHandlingPanelOKButton)
        {
            guard let newFileURL = saveFilePanel.url
                else
            {
                DLog("Bad file name")
                return
            }
            
            do {
                try fileString.write(to: newFileURL, atomically: true, encoding: String.Encoding.utf8)
            }
            catch {
                ALog("Could not write file!")
            }
            
            DLog("Finished writing file")
        }
        
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
        
        if (self.theModel != nil)
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save them before proceeding?"
            saveYesOrNo.alertStyle = NSAlertStyle.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSAlertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
            
            DLog("Deleting existing phase")
            self.phaseDefinition = nil
            self.theModel = nil
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
