//
//  SourceDefinitionDlog.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class SourceDefinitionDlog: NSWindowController {

    @IBOutlet var waveformTypeDropDown: NSPopUpButton!
    @IBOutlet var peakValueEditField: NSTextField!
    
    // var waveFormType = PCH_Source.Types.FullWave
    // var peakVoltage = 0.0
    
    var source:PCH_Source?
    
    // override the windowNibName property becuase we only ever open this nib file from this controller
    override var windowNibName: NSNib.Name!
    {
        return "SourceDefinitionDlog"
    }
    
    override func windowDidLoad()
    {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    func runDialog() -> PCH_Source?
    {
        NSApp.runModal(for: self.window!)
        
        return self.source
    }
    
    @IBAction func okayButtonPushed(_ sender: Any)
    {
        let selectedWaveFormIndex = self.waveformTypeDropDown.indexOfSelectedItem
        
        let waveForm = PCH_Source.Types.FullWave
        
        // The next if clause should set the waveForm depending on the selection (once they are implemented)
        if selectedWaveFormIndex != 0
        {
            // This shouldn't happen
            ALog("Unimplemented waveform type!")
        }
        
        self.source = PCH_Source(type: waveForm, pkVoltage: self.peakValueEditField.doubleValue * 1000.0)
        
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
    @IBAction func cancelButtonPushed(_ sender: Any)
    {
        self.source = nil
        NSApp.stopModal()
        self.window!.orderOut(self)
    }
    
}
