//
//  Coil.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Foundation

struct Coil
{
    /// The name to which we will refer to the coil (the node and device names will also incorporate this string, which is usually in the form "LV", "HV", etc.
    let coilName:String
    
    /// coilRadialPosition is relative to the core: 0 is closest, 1 is next, etc.
    let coilRadialPosition:Int
    
    /// The absolute-value of the current through the coil in amperes
    let amps:Double
    
    /// The direction of the current through the coil (-1,0,1)
    let currentDirection:Int
    
    /// The full coil-height capacitance to the previous coil
    let capacitanceToPreviousCoil:Double

    /// The innerRadius of the coil
    let innerRadius:Double
    
    var sections:[AxialSection]
    
    func Height() -> Double
    {
        var result = 0.0
        for nextSection in sections
        {
            result += nextSection.Height()
        }
        
        return result
    }
}

struct AxialSection
{
    /// sectionAxialPosition is relative to the bottom yoke: 0 is closest (lowest), 1 is next, etc.
    let sectionAxialPosition:Int
    
    /// The total number of turns in the section
    let turns:Double
    
    /// The number of disks that make up the section
    let numDisks:Int
    
    /// Capacitances
    let topDiskSerialCapacitance:Double
    let bottomDiskSerialCapacitance:Double
    let commonDiskSerialCapacitance:Double
    
    /// Static ring info (for drawing)
    let topStaticRing:Bool
    let bottomStaticRing:Bool
    
    /// Boolean indicating whether the section is interleaved
    let isInterleaved:Bool
    
    let diskResistance:Double
    
    /// The size of the cross-section of a single disk (shrunk)
    let diskSize:NSSize
    
    /// The shrunk axial dimension between disks
    let interDiskDimn:Double
    
    /// The spacer on top of this section (0.0 for the topmost section of a coil)
    let overTopDiskDimn:Double
    
    func Height() -> Double
    {
        let result = Double(numDisks) * Double(diskSize.height) + Double(numDisks - 1) * interDiskDimn + overTopDiskDimn
        
        return result
    }
}
