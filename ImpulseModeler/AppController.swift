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
    
    @IBAction func handleCreateModel(_ sender: AnyObject)
    {
        
    }
    
    // Menu Handlers
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
