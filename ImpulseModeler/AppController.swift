//
//  AppController.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Foundation
import Cocoa

// A helper class to allow saving to and restoring from files
class PhaseModel:NSObject, NSCoding
{
    enum Units:Int {
        case inch
        case mm
        case meters
    }
    
    let phase:Phase
    let model:[PCH_DiskSection]
    let units:Units
    
    init(phase:Phase, model:[PCH_DiskSection], units:Units)
    {
        self.phase = phase
        // let gndSectionArray = [AppController.gndSection]
        self.model = model // + gndSectionArray
        self.units = units
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        
        let phase = aDecoder.decodeObject(forKey: "Phase") as! Phase
        let model = aDecoder.decodeObject(forKey: "Model") as! [PCH_DiskSection]
        var units:Units = .inch
        if aDecoder.containsValue(forKey: "Units")
        {
            if let tryUnits = Units(rawValue: aDecoder.decodeInteger(forKey: "Units"))
            {
                units = tryUnits
            }
        }
        
        self.init(phase:phase, model:model, units:units)
    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.phase, forKey: "Phase")
        aCoder.encode(self.model, forKey: "Model")
        aCoder.encode(self.units.rawValue, forKey: "Units")
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

// Constants for the "generator" and "ground" nodes
let GENERATOR_NODE_NUMBER = -2
let GROUND_NODE_NUMBER = -1

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
    @IBOutlet weak var metricItemMM: NSMenuItem!
    @IBOutlet weak var metricItemM: NSMenuItem!
    
    
    var unitFactor = 25.4 / 1000.0
    
    @IBOutlet weak var createModelMenuItem: NSMenuItem!
    @IBOutlet weak var saveCirFileMenuItem: NSMenuItem!
    @IBOutlet weak var runSimMenuItem: NSMenuItem!
    @IBOutlet weak var saveModelMenuItem: NSMenuItem!
    @IBOutlet weak var modifyModelMenuItem: NSMenuItem!
    @IBOutlet weak var saveMatricesMenuItem: NSMenuItem!
    

    @IBOutlet weak var mainWindow: NSWindow!
    
    // The currently showing progress indicator (used for long operations like calculating mutual impedances and running impulse simulations)
    let currentProgressIndicator:PCH_ProgressIndicatorWindow
    
    // The model in the format required by the routine for making a spice ".cir" file
    var theModel:[PCH_DiskSection]?
    
    // to avoid asking to save for nothing
    var currentModelIsDirty:Bool = false
    
    override init()
    {
        // This is the best way I've found to actually "preload" the progress indicator window class and make it "load" its window from the nib
        self.currentProgressIndicator = PCH_ProgressIndicatorWindow()
        super.init() // doesn't do anything but Swift complains if we don't call this (at least, it USED to)
        
    }
    
    
    
    // Debugging routine to test things that take a long time
    @IBAction func handleDoSomethingLong(_ sender: Any)
    {
        if self.currentProgressIndicator.window == nil
        {
            DLog("Fuck!")
            return
        }
        
        let iterations = 100000
        let updateIndicatorSteps = 1
        
        self.currentProgressIndicator.UpdateIndicator(value: 0.0, minValue: 0.0, maxValue: Double(iterations), text: "Testing lots of iterations, dude")
        
        self.mainWindow.beginSheet(self.currentProgressIndicator.window!, completionHandler: { (response) in
            
            DLog("Progress Indicator closed!")
        })
        
        let myQueue = DispatchQueue(label:"com.huberistech.serial")
        
        myQueue.async {
            
            for i in 0..<iterations
            {
                let _ = 6.6789 * Double(i) / 1234.5
                
                if i % updateIndicatorSteps == 0
                {
                    DLog("Updating with i = \(i)")
                    
                    DispatchQueue.main.async {
                        self.currentProgressIndicator.UpdateIndicator(value: Double(i))
                    }
                }
            }
            
            self.mainWindow.endSheet(self.currentProgressIndicator.window!)
            
            DLog("Done.")
        }
    }
    
    func totalSectionsInPhase(_ phase:Phase) -> Int
    {
        var result = 0
        
        for nextCoil in phase.coils
        {
            result += Int(round(nextCoil.numDisks))
        }
        
        return result
    }
    
    func openModel(_ url:URL) -> Bool
    {
        if (self.theModel != nil) && self.currentModelIsDirty
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlert.Style.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
        }
        
        if let archive = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? PhaseModel
        {
            self.theModel = []
            self.phaseDefinition = archive.phase
            
            for nextSection in archive.model
            {
                if nextSection.N == 0.0
                {
                    DLog("Got one!")
                }
                else
                {
                    self.theModel!.append(nextSection)
                }
            }
            
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            
            self.currentModelIsDirty = false
            
            return true
        }
        else
        {
            let alertNoFile = NSAlert()
            alertNoFile.messageText = "Invalid file or file does not exist"
            alertNoFile.alertStyle = NSAlert.Style.warning
            alertNoFile.addButton(withTitle: "Ok")
            alertNoFile.runModal()
            
            return false
        }
    }
    
    // Menu Handlers
    @IBAction func handleOpenDesignFile(_ sender: Any)
    {
        if (self.theModel != nil) && self.currentModelIsDirty
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlert.Style.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
        }
        
        // Handler to open a design file created by Excel (same as the file for AndersenFE)
        let openFilePanel = NSOpenPanel()
        
        openFilePanel.title = "Open Excel-generated Design File"
        openFilePanel.message = "Select the file to open"
        openFilePanel.allowedFileTypes = ["txt"]
        openFilePanel.allowsOtherFileTypes = false
        
        if openFilePanel.runModal() == .OK
        {
            if let xlFile = openFilePanel.url
            {
                do
                {
                    let designFile = try ExcelDesignFile(withURL: xlFile)
                    
                    var coilNames = ["LV", "HV", "RV"]
                    if (designFile.numCoils > 3)
                    {
                        coilNames.insert("TV", at: 0)
                    }
                    var defaultNameString = ""
                    for nextName in coilNames
                    {
                        defaultNameString += nextName + ", "
                    }
                    
                    defaultNameString.removeLast(2)
                    
                    let coilNameAlert = NSAlert()
                    coilNameAlert.alertStyle = .informational
                    coilNameAlert.messageText = "The design file shows \(designFile.numCoils) coils."
                    coilNameAlert.informativeText = "Do you wish to use default names (\(defaultNameString)) or deine your own custom names?"
                    coilNameAlert.addButton(withTitle: "Default")
                    coilNameAlert.addButton(withTitle: "Custom")
                    
                    if coilNameAlert.runModal() == .alertSecondButtonReturn
                    {
                        // Get the custom names
                        let getNamesDlog = GetCoilNamesDlogBox(numCoils: designFile.numCoils)
                        
                        if getNamesDlog.runModal() == .OK
                        {
                            coilNames = getNamesDlog.namesArray
                        }
                    }
                    
                    let newCore = Core(diameter: designFile.coreDiameter, height: designFile.windowHt, legCenters: designFile.legCenters)
                    
                    var newCoils:[Coil] = []
                    
                    var lastCoil = Coil()
                    
                    var lastOD = designFile.coreDiameter
                    var lastHt = designFile.coils[0].effectiveHt
                    
                    for nextCoilIndex in 0..<8
                    {
                        let terminal = designFile.terminals[nextCoilIndex]
                        let coil = designFile.coils[nextCoilIndex]
                        if terminal.coilIndex < 8
                        {
                            let capToPreviousCoil = Coil.CapacitanceBetweenCoils(innerOD: lastOD, outerID: coil.coilID, innerH: lastHt, outerH: coil.effectiveHt, numSpacers: Int(coil.numRadialColumns))
                            
                            DLog("Cap to prev coil: \(capToPreviousCoil)")
                            
                            let impCoil = Coil.CoilUsing(xlFileCoil: coil, coilName: coilNames[nextCoilIndex], coilPosition: nextCoilIndex, connection: terminal.connection, amps: terminal.phaseAmps, currentDirection: terminal.currentDirection, capacitanceToPreviousCoil: capToPreviousCoil, capacitanceToGround: 0.0, eddyLossPercentage: coil.eddyLossAvePU, phaseNum: 1)
                            
                            newCoils.append(impCoil)
                            
                            lastCoil = impCoil
                            lastOD = coil.coilOD
                            lastHt = coil.effectiveHt
                        }
                    }
                    
                    // calculate lastCoil's capacitances to other phases and to the tank
                    let gndCap = Coil.CapacitanceBetweenPhases(legCenters: newCore.legCenters, coilOD: lastOD, coilHt: lastHt) + Coil.CapacitanceFromCoilToTank(coilOD: lastOD, coilHt: lastHt, tankDim: designFile.tankDepth)
                    
                    DLog("Outer Coil Sum of Cap between coils and Cap to tank: \(gndCap)")
                    lastCoil.capacitanceToGround = gndCap
                    
                    self.inchItem.state = .off
                    self.metricItemMM.state = .off
                    self.metricItemM.state = .on
                    self.unitFactor = 1.0
                    
                    self.phaseDefinition = Phase(core: newCore, coils: newCoils)
                    
                    self.theModel = []
                    
                    // self.handleCreateModel(self)
                    
                }
                catch
                {
                    let alert = NSAlert(error: error)
                    let _ = alert.runModal()
                    return
                }
            }
            else
            {
                ALog("Couldn't get file")
            }
        }
        
    }
    
    @IBAction func handleOpenModel(_ sender: AnyObject)
    {
        if (self.theModel != nil) && self.currentModelIsDirty
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlert.Style.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
            {
                self.handleSaveModel(self)
            }
        }
        
        let openFilePanel = NSOpenPanel()
        
        openFilePanel.title = "Open Model"
        openFilePanel.message = "Select the model to open"
        openFilePanel.allowedFileTypes = ["impmdl"]
        openFilePanel.allowsOtherFileTypes = false
        
        if (openFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
        {
            // let testURL = openFilePanel.url!
            // let testURLPath = testURL.path
            
            if let archive = NSKeyedUnarchiver.unarchiveObject(withFile: openFilePanel.url!.path) as? PhaseModel
            {
                self.theModel = []
                self.phaseDefinition = archive.phase
                
                if archive.units == .inch
                {
                    self.inchItem.state = .on
                    self.metricItemMM.state = .off
                    self.metricItemM.state = .off
                    self.unitFactor = 25.4 / 1000.0
                }
                else if archive.units == .mm
                {
                    self.inchItem.state = .off
                    self.metricItemMM.state = .on
                    self.metricItemM.state = .off
                    self.unitFactor = 1.0 / 1000.0
                }
                else
                {
                    self.inchItem.state = .off
                    self.metricItemMM.state = .off
                    self.metricItemM.state = .on
                    self.unitFactor = 1.0
                }
                
                for nextSection in archive.model
                {
                    if nextSection.N == 0.0
                    {
                        DLog("Got one!")
                    }
                    else
                    {
                        self.theModel!.append(nextSection)
                    }
                }
        
                NSDocumentController.shared.noteNewRecentDocumentURL(openFilePanel.url!)
                
                self.currentModelIsDirty = false
            }
        }
    }
    
    @IBAction func handleSaveSectionData(_ sender: Any)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Section Data"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["txt"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if saveFilePanel.runModal() == .OK
        {
            guard let newFileURL = saveFilePanel.url
            else
            {
                DLog("Bad file name")
                return
            }
            
            guard let sectionModel = self.theModel else
            {
                DLog("Model does not exist!")
                return
            }
            
            if sectionModel.count == 0
            {
                DLog("Model has no sections")
                return
            }
            
            var fileString = "Section Data\n\n"
            for nextSection in sectionModel
            {
                fileString += "\(nextSection)\n"
            }
            
            do
            {
                try fileString.write(to: newFileURL, atomically: true, encoding: .utf16)
            }
            catch
            {
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return
            }
        }
    }
    
    
    @IBAction func handleSaveModel(_ sender: AnyObject)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Model"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["impmdl"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
        {
            guard let newFileURL = saveFilePanel.url
            else
            {
                DLog("Bad file name")
                return
            }
            
            var units:PhaseModel.Units = .inch
            if self.metricItemMM.state == .on
            {
                units = .mm
            }
            else if self.metricItemM.state == .on
            {
                units = .meters
            }
            
            let archive = PhaseModel(phase: self.phaseDefinition!, model: self.theModel!, units:units)
            
            if NSKeyedArchiver.archiveRootObject(archive, toFile: newFileURL.path)
            {
                self.currentModelIsDirty = false
            }
            else
            {
                DLog("Couldn't write the file!")
            }
            
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
        
        // bbModel.C.SaveAsCSV()
        
        let connDlog = ConnectionDlog()
        guard let testConnection = connDlog.runDialog(theModel: self.theModel!)
        else
        {
            DLog("User chose cancel")
            return
        }
        
        // The first thing we do is extract all the impulse-generator connection nodes. We want to end up with only one node that is actually connected to the generator and that node should be connected to all the other nodes that are also connected to the generator. Finally, those node's connections should be deleted from the list.
        var genNodes = Set<Int>()
        // var newConnectionArray = Array<(from:Int, to:[Int])>()
        for nextConnection in testConnection
        {
            if nextConnection.to.contains(-2)
            {
                genNodes.insert(nextConnection.from)
                
                for nextToNode in nextConnection.to
                {
                    if (nextToNode != -2)
                    {
                        genNodes.insert(nextToNode)
                    }
                }
            }
        }
        
        // At this point we have a set that MUST contain at least one node
        if genNodes.count == 0
        {
            // Put up a fancy dialog here
            DLog("No generator connection!")
            return
        }
        
        // Now we'll go through the array of connections over and over until all generator-connected nodes are in genNodes
        var doneFindingGenNodes = false
        while !doneFindingGenNodes
        {
            doneFindingGenNodes = true
            
            for nextConnection in testConnection
            {
                if genNodes.contains(nextConnection.from)
                {
                    for nextToNode in nextConnection.to
                    {
                        if (nextToNode != -2)
                        {
                            if (!genNodes.contains(nextToNode))
                            {
                                genNodes.insert(nextToNode)
                                doneFindingGenNodes = false
                            }
                        }
                    }
                }
            }
        }
    
        var newConnectionArray = testConnection.filter({!genNodes.contains($0.from)})
        let sourceConnNode = genNodes.removeFirst()
        
        if genNodes.count > 0
        {
            let genNodeArray = Array(genNodes)
            newConnectionArray.append((from:sourceConnNode, to:genNodeArray))
        }
        
        // We need to make sure that each non-ground connected node only turns up once in each connection set (either as the from: or one of the to: nodes)
        // start by setting up a set for each connection
        var connSetArray:[Set<Int>] = []
        for nextConn in newConnectionArray
        {
            var newSet:Set<Int> = [nextConn.from]
            for nextTo in nextConn.to
            {
                newSet.insert(nextTo)
            }
            
            connSetArray.append(newSet)
        }
        
        // combine the sets as needed
        var combinedSetArray:[Set<Int>] = []
        while connSetArray.count > 0
        {
            var combSet = connSetArray.removeFirst()
            
            
            
            combinedSetArray.append(combSet)
        }
        
        
        var tConnArray:[(fromNode: Int, toNodes: [Int])] = []
        for nextConn in newConnectionArray
        {
            let nextInt = nextConn.from
            let nextArray = nextConn.to
            
            tConnArray.append((nextInt, nextArray))
        }
        
        // we'll set up three time step structs for BIL simulations
        var timeStepArray:[PCH_BB_TimeStepInfo] = []
        timeStepArray.append(PCH_BB_TimeStepInfo(startTime: 0.0, endTime: 5.0E-6, timeStep: 1.0E-9, saveTimeStep: 10.0E-9))
        timeStepArray.append(PCH_BB_TimeStepInfo(startTime: 5.0E-6, endTime: 20.0E-6, timeStep: 5.0E-9, saveTimeStep: 50.0E-9))
        timeStepArray.append(PCH_BB_TimeStepInfo(startTime: 20.0E-6, endTime: 100.0E-6, timeStep: 100.0E-9, saveTimeStep: 100.0E-9))
        
        // uodate the progress indicator to reflect the maximum time of the impulse shot
        self.currentProgressIndicator.UpdateIndicator(value: 0.0, minValue: 0.0, maxValue: 100.0E-6, text: "Running Simulation...")
        
        // open the sheet with the progress indicator
        self.mainWindow.beginSheet(self.currentProgressIndicator.window!, completionHandler: {responseCode in
            DLog("Ended sheet")
        })
        
        // create a serial queue
        let simQueue = DispatchQueue(label: "com.huberistech.bil_simulation")
        
        // we need to call .async with our queue so that a non-main thread is created
        simQueue.async {
            
            guard let resultMatrices = bbModel.SimulateWithConnections(tConnArray, sourceConnection: (testSource, sourceConnNode), timeSteps: timeStepArray, progIndicatorWindow:self.currentProgressIndicator)
                else
            {
                DLog("Simulation failed!")
                // if we get failure, we need to close the progress indicator before returning
                DispatchQueue.main.sync { self.mainWindow.endSheet(self.currentProgressIndicator.window!) }
                return
            }
            
            
            // we want to save the impres file using an NSSavePanel, but that is UI, which CANNOT be done in any thread except the main thread. We dispatch a sync call to the main thread to take care of this.
            DispatchQueue.main.sync {
                
                self.mainWindow.endSheet(self.currentProgressIndicator.window!)
                
                var bbModelSections = Array<PCH_BB_ModelSection>()
                for nextSection in self.theModel!
                {
                    let nextBBSection = PCH_BB_ModelSection(inNode: nextSection.data.nodes.inNode, outNode: nextSection.data.nodes.outNode, name: nextSection.data.sectionID, zDims:(Double(nextSection.diskRect.origin.y), Double(nextSection.diskRect.origin.y + nextSection.diskRect.size.height)))
                    
                    bbModelSections.append(nextBBSection)
                }
                
                let bbModelOutput = PCH_BlueBookModelOutput(timeArray: resultMatrices.times, sections:bbModelSections, voltsMatrix: resultMatrices.V, ampsMatrix: resultMatrices.I, vDiffMatrix: resultMatrices.vDiff)
                
                let saveFilePanel = NSSavePanel()
                
                saveFilePanel.title = "Save Impulse Simulation Results"
                saveFilePanel.canCreateDirectories = true
                saveFilePanel.allowedFileTypes = ["impres"]
                saveFilePanel.allowsOtherFileTypes = false
                
                if (saveFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
                {
                    if let newFileURL = saveFilePanel.url
                    {
                        // This is required to be able to open the files in different programs with the same class.
                        NSKeyedArchiver.setClassName("ImpulseResult", for: PCH_BlueBookModelOutput.self)
                        NSKeyedArchiver.setClassName("BBSections", for: PCH_BB_ModelSection.self)
                        let archiveResult = NSKeyedArchiver.archiveRootObject(bbModelOutput, toFile: newFileURL.path)
                        
                        if (!archiveResult)
                        {
                            DLog("Couldn't write the file!")
                        }
                        
                        DLog("Finished writing file")
                    }
                    else
                    {
                        DLog("Bad file URL!")
                    }
                }
                
            } // end main.sync
            
        } // end simQueue.async
        
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
        
        if (theModel != nil) && self.currentModelIsDirty
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save it before proceeding?"
            saveYesOrNo.alertStyle = NSAlert.Style.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
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
            
            var zCurrent = nextCoil.CoilBottom(phase.core.height * phase.core.htFactor, centerOffset: phase.core.coilCenterOffset) * unitFactor
            let coilID = nextCoil.coilName
            
            DLog("Creating disks")
            
            let coilAvgEddyLossPercentage = nextCoil.eddyLossPercentage
            
            var sectionNumberOffset = 0
            for nextAxialSection in axialSections
            {
                // we need to make sure that the user didn't mistakenly add another section when he didn't really want to
                if nextAxialSection.numDisks <= 0
                {
                    continue
                }
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
                    let theNewSection = PCH_DiskSection(coilRef: nextCoil.coilRadialPosition, diskRect: diskRect, N: turnsPerDisk, J: turnsPerDisk * nextCoil.amps * (nextCoil.currentDirection < 0 ? -1.0 : 1.0) / diskArea, windHt: phase.core.height * unitFactor, coreRadius: phase.core.diameter * unitFactor / 2.0, secData: sectionData)
                    
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
                let capacitancePerUnitHeight = coilCapacitanceToGround / (theCoil.Height() * unitFactor)
                
                for sectionIndex in currentStartIndex...currentEndIndex
                {
                    let currentSection = self.theModel![sectionIndex]
                    
                    let diskCapToGnd = capacitancePerUnitHeight * Double(currentSection.diskRect.height)
                    
                    currentSection.data.shuntCapacitances[AppController.gndSection.data.sectionID] = diskCapToGnd
                    // currentSection.data.shuntCaps[AppController.gndSection] = diskCapToGnd
                    
                }
            }
            
            // we only go through the next loop if this isn't the first coil AND the capacitance to previous coil is non-zero (If it is zero, this must be a coil on another phase. This is a rather lame method in that it forces the modelling of only a single coil on "other" phases)
            if (theCoilNum > 0) && (theCoil.capacitanceToPreviousCoil != 0)
            {
                // let previousEndIndex = currentStartIndex - 1
                
                let maxSections = round(max(phase.coils[theCoilNum].numDisks, phase.coils[theCoilNum-1].numDisks))
                
                // This is kinda wrong, in that we really should consider the height of each section like we do above for ground capacitances but it gets complicated with the 2 coils that we need to consider.
                // TODO: Fix inter-coil capacitances to use capacitance per unit height
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
        
        let diskCount = Double(diskArray.count)
        
        self.currentProgressIndicator.UpdateIndicator(value: 0.0, minValue: 0.0, maxValue: diskCount, text: "Calculating mutual inductances...")
        
        // open the sheet with the progress indicator
        self.mainWindow.beginSheet(self.currentProgressIndicator.window!, completionHandler: {responseCode in
            DLog("Ended sheet")
        })
        
        // create a serial queue
        let mutIndQueue = DispatchQueue(label: "com.huberistech.mutual_inductance_calculation")
        
        // we need to call .async with our queue so that a non-main thread is created
        mutIndQueue.async {
            
            DLog("Calculating mutual inductances")
            while diskArray.count > 0
            {
                DispatchQueue.main.async {
                    self.currentProgressIndicator.UpdateIndicator(value: diskCount - Double(diskArray.count))
                }
                
                let nDisk = diskArray.remove(at: 0)
                
                DLog("Calculating to: \(nDisk.data.sectionID)")
                
                // let nIsUncoupled = (phase.coils[nDisk.coilRef].phaseNum == 0 ? true : false)
                
                for otherDisk in diskArray
                {
                    // let otherIsUncoupled = (phase.coils[otherDisk.coilRef].phaseNum == 0 ? true : false)
                    
                    if (phase.coils[nDisk.coilRef].phaseNum != phase.coils[otherDisk.coilRef].phaseNum)
                    {
                        continue
                    }
                    
                    let mutInd = nDisk.MutualInductanceTo(otherDisk)
                    
                    let mutIndCoeff = mutInd / sqrt(nDisk.data.selfInductance * otherDisk.data.selfInductance)
                    if ( /* mutIndCoeff < 0.0 || */ mutIndCoeff > 1.0)
                    {
                        ALog("Illegal Mutual Inductance:\(mutInd); this.SelfInd:\(nDisk.data.selfInductance); that.SelfInd:\(otherDisk.data.selfInductance)")
                    }
                    
                    nDisk.data.mutualInductances[otherDisk.data.sectionID] = mutInd
                    otherDisk.data.mutualInductances[nDisk.data.sectionID] = mutInd
                    
                    nDisk.data.mutIndCoeff[otherDisk.data.sectionID] = mutIndCoeff
                    otherDisk.data.mutIndCoeff[nDisk.data.sectionID] = mutIndCoeff
                    
                }
            }
            
            DispatchQueue.main.async {self.mainWindow.endSheet(self.currentProgressIndicator.window!)}
            
            DLog("Done muties!")
            
        } // end mutIndQueue.async
        
        self.currentModelIsDirty = true
        
    }
    
    // Save the C, M, R, A, and B matrices in CSV style. All the created file names will have the same prefix (supplied by the user) with an appended '_M', _C', '_R', '_A', '_B' to indicate the different matrices.
    @IBAction func handleSaveMatrices(_ sender: Any)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Model Matrices"
        saveFilePanel.message = "Enter the prefix to use for the files"
        saveFilePanel.nameFieldLabel = "Prefix:"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["txt"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
        {
            guard let filePrefixUrl = saveFilePanel.url
                else
            {
                DLog("Bad file name")
                return
            }
            
            let filePrefix = filePrefixUrl.deletingPathExtension().lastPathComponent
            
            let pathUrl = filePrefixUrl.deletingLastPathComponent()
            
            let bbModel = PCH_BlueBookModel(theModel: self.theModel!, phase: self.phaseDefinition!)
            
            let matrices = [bbModel.M, bbModel.C, bbModel.R, bbModel.A, bbModel.B]
            let fileSuffixes = ["_M", "_C", "_R", "_A", "_B"]
            
            for i in 0..<matrices.count
            {
                var fileString = matrices[i].description
                fileString.removeFirst()
                
                // fix column beginnings and ends
                fileString = fileString.replacingOccurrences(of: "| ", with: "")
                fileString = fileString.replacingOccurrences(of: " |", with: "")
                // replace spaces between entries with commas
                fileString = fileString.replacingOccurrences(of: "   ", with: ",")
                
                let currFileSuffix = filePrefix + fileSuffixes[i] + ".txt"
                let fileURL = pathUrl.appendingPathComponent(currFileSuffix)
                
                do {
                    try fileString.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
                }
                catch {
                    ALog("Could not write file!")
                }
            }
            
            DLog("Done writing files")
        }
    }
    
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
    {
        if (menuItem == self.createModelMenuItem)
        {
            return self.phaseDefinition != nil && self.theModel == nil
        }
        
        if menuItem == self.saveModelMenuItem
        {
            return self.theModel != nil && self.currentModelIsDirty
        }
        
        if (menuItem == self.saveCirFileMenuItem) || (menuItem == self.runSimMenuItem) || (menuItem == self.modifyModelMenuItem) || (menuItem == self.saveMatricesMenuItem)
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
            
            let coilName = String(nextSectionID.prefix(2))
            
            // let diskNum = PCH_StrRight(nextSectionID, length: 3)
            
            // let nextDiskNum = String(format: "%03d", Int(diskNum)! + 1)
            
            let inNode = String(format: "%@I%03d", coilName, nextDisk.data.nodes.inNode)
            let outNode = String(format: "%@I%03d", coilName, nextDisk.data.nodes.outNode)
            let midNode = String(format: "%@M%03d", coilName, nextDisk.data.nodes.inNode)
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
                
                let nsName1 = String(format: "CP1%@%03d", nextSectionID, shuntCapSerialNum)
                let nsName2 = String(format: "CP2%@%03d", nextSectionID, shuntCapSerialNum)
                
                /*
                 let shuntID = nextShuntCap.0
                 
                 // make sure that this capacitance is not already done
                 if dSections.contains(shuntID)
                 {
                 continue
                 }
                 */
                
                var shuntNode1 = String()
                var shuntNode2 = ""
                if (nextShuntSection.coilRef == -1)
                {
                    shuntNode1 = "0"
                    shuntNode2 = "0"
                }
                else
                {
                    shuntNode1 = String(format: "%@I%03d", coilArray[nextShuntSection.coilRef].coilName, nextShuntSection.data.nodes.inNode)
                    shuntNode2 = String(format: "%@I%03d", coilArray[nextShuntSection.coilRef].coilName, nextShuntSection.data.nodes.outNode)
                    
                }
                
                fString += nsName1 + " " + inNode + " " + shuntNode1 + String(format: " %.4E\n", nextShuntCap.value / 2.0)
                fString += nsName2 + " " + outNode + " " + shuntNode2 + String(format: " %.4E\n", nextShuntCap.value / 2.0)
                
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
            
            var firstDiskInCoilIndex = 0
            if i > 0
            {
                for j in 1...i
                {
                    firstDiskInCoilIndex += Int(round(coilArray[j-1].numDisks))
                }
            }
            fString += String(format: "R%@BOT %@BOT %@I%03d 1.0E-9\n", nextID, nextID, nextID, theModel![firstDiskInCoilIndex].data.nodes.inNode)
            
            let middleDiskInCoilIndex = firstDiskInCoilIndex + Int(round(coilArray[i].numDisks)) / 2 - 1
            fString += String(format: "R%@CEN %@CEN %@I%03d 1.0E-9\n", nextID, nextID, nextID, theModel![middleDiskInCoilIndex].data.nodes.outNode)
            
            let lastDiskInCoilIndex = firstDiskInCoilIndex + Int(round(coilArray[i].numDisks)) - 1
            fString += String(format: "R%@TOP %@TOP %@I%03d 1.0E-9\n", nextID, nextID, nextID, theModel![lastDiskInCoilIndex].data.nodes.outNode)
        }
        
        
        // TODO: Add code for the connection that interests us (very particular to the case we're testing)
        fString += "\n* Connections\n"
        fString += "RLVNEUT LVBOT 0 1.0E-9\n"
        fString += "RLVLINE LVTOP 0 1.0E-9\n"
        fString += "RHVNEUT HVBOT 0 1.0E-9\n\n"
        
        // The shot
        fString += "* Impulse shot\nVBIL HVTOP 0 EXP(0 360.5k 0 2.2E-7 1.0E-6 7.0E-5)\n\n"
        
        // Options required to make this work most of the time
        fString += "* options for LTSpice\n.OPTIONS reltol=0.02 trtol=7 abstol=1e-6 vntol=1e-4 method=gear\n\n"
        
        fString += ".TRAN 10.0ns 100us\n\n.END"
        
        self.saveFileWithString(fString)
    }
    
    func saveFileWithString(_ fileString:String)
    {
        let saveFilePanel = NSSavePanel()
        
        saveFilePanel.title = "Save Spice data"
        saveFilePanel.canCreateDirectories = true
        saveFilePanel.allowedFileTypes = ["cir"]
        saveFilePanel.allowsOtherFileTypes = false
        
        if (saveFilePanel.runModal().rawValue == NSFileHandlingPanelOKButton)
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
            self.inchItem.state = .on
            self.metricItemMM.state = .off
            self.metricItemM.state = .off
            self.unitFactor = 25.4 / 1000.0
        }
        else if wMenu == self.metricItemMM
        {
            self.inchItem.state = .off
            self.metricItemMM.state = .on
            self.metricItemM.state = .off
            self.unitFactor = 1.0 / 1000.0
        }
        else if wMenu == self.metricItemM
        {
            self.inchItem.state = .off
            self.metricItemMM.state = .off
            self.metricItemM.state = .on
            self.unitFactor = 1.0
        }
    }
    
    
    @IBAction func handleNew(_ sender: AnyObject)
    {
        DLog("Handling New menu command")
        
        let oldPhase = self.phaseDefinition
        
        if (self.theModel != nil) && self.currentModelIsDirty
        {
            let saveYesOrNo = NSAlert()
            saveYesOrNo.messageText = "This will destroy the current model! Do you wish to save them before proceeding?"
            saveYesOrNo.alertStyle = NSAlert.Style.warning
            saveYesOrNo.addButton(withTitle: "Yes")
            saveYesOrNo.addButton(withTitle: "No")
            
            if (saveYesOrNo.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn)
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
        
        self.currentModelIsDirty = true
    }
}
