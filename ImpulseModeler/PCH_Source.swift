//
//  PCH_Source.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-01.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class PCH_Source: NSObject {

    // For now, only the FullWave option is defined, and assumes a 1.2 x 50 µs waveform
    enum Types {case FullWave}
    
    let pkVoltage:Double
    let type:Types
        
    init(type:Types, pkVoltage:Double) {
        
        self.type = type
        self.pkVoltage = pkVoltage
    }
    
    func V(_ t:Double) -> Double
    {
        if (self.type == Types.FullWave)
        {
            let k1 = 14285.0
            let k2 = 3.3333333E6
            
            let v0 = 1.03 * pkVoltage
            
            return v0 * (e(-k1*t) - e(-k2*t))
        }
        
        ALog("Undefined waveform")
        return 0.0
    }
    
    func dV(_ t:Double) -> Double
    {
        if (self.type == Types.FullWave)
        {
            let k1 = 14285.0
            let k2 = 3.3333333E6
            
            let v0 = 1.03 * pkVoltage
            
            return v0 * (k2 * e(-k2 * t) - k1 * e(-k1 * t))
        }
        
        ALog("Undefined waveform")
        return 0.0
    }
}
