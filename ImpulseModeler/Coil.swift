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
    /// coilPosition is relative to the core: 1 is closest, 2 is next, etc.
    let coilPosition:Int
    
    /// The innerRadius of the coil
    let innerRadius:Double
    
    /// The number of disks that make up the coil
    let numDisks:Int
    
    /// The number of disks that are interleaved at the top of the coil
    let numTopInterleavedDisks:Int
    /// The number of disks that are interleaved at the bottom of the coil
    let numBottomInterleavedDisks:Int
    
    /// The size of the cross-section of a single disk
    let diskSize:NSSize
    
    /// The axial dimension between disks
    let interDiskDimn:Double

}
