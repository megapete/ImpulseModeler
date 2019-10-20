//
//  Coil.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Foundation

// NOTE (Oct. 2019): For now, helical, layer, and sheet windings are represented as a "single disc". This will eventually change but it will need an extensive rewrite of this class. 

class Coil:NSObject, NSCoding
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
    
    /// Capacitance to the tank or other ground (usually 0, except for the last coil, or capacitance to a shield)
    let capacitanceToGround:Double

    /// The innerRadius of the coil
    let innerRadius:Double
    
    /// The average eddy-loss percentage of dc resistance for the coil
    let eddyLossPercentage:Double
    
    /// Variable to decide if we need to consider intercoil capacitances and mutual inductances (ie: is this coil decoupled from the others?). For now, we use the simplification that the "main" coils are on phase 1, while any others are on phases 2 or 3. Note that for now, only a single coil can be defined for phase 2 and/or 3
    let phaseNum:Int
    
    var sections:[AxialSection]?
    
    init(coilName:String, coilRadialPosition:Int, amps:Double, currentDirection:Int, capacitanceToPreviousCoil:Double, capacitanceToGround:Double, innerRadius:Double, eddyLossPercentage:Double, phaseNum:Int, sections:[AxialSection]? = nil)
    {
        self.coilName = coilName
        self.coilRadialPosition = coilRadialPosition
        self.amps = amps
        self.currentDirection = currentDirection
        self.capacitanceToPreviousCoil = capacitanceToPreviousCoil
        self.capacitanceToGround = capacitanceToGround
        self.innerRadius = innerRadius
        self.eddyLossPercentage = eddyLossPercentage
        self.sections = sections
        self.phaseNum = phaseNum
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let coilName = aDecoder.decodeObject(forKey: "CoilName") as! String
        let coilRadialPosition = aDecoder.decodeInteger(forKey: "CoilRadialPosition")
        let amps = aDecoder.decodeDouble(forKey: "Amps")
        let currentDirection = aDecoder.decodeInteger(forKey: "CurrentDirection")
        let capacitanceToPreviousCoil = aDecoder.decodeDouble(forKey: "CapToPreviousCoil")
        let capacitanceToGround = aDecoder.decodeDouble(forKey: "CapToGround")
        let innerRadius = aDecoder.decodeDouble(forKey: "InnerRadius")
        let eddyLossPercentage = aDecoder.decodeDouble(forKey: "EddyLossPercentage")
        let sections = aDecoder.decodeObject(forKey: "Sections") as! [AxialSection]
        
        var validSections:[AxialSection] = []
        for nextSection in sections
        {
            if nextSection.numDisks > 0
            {
                validSections.append(nextSection)
            }
        }
        
        let phaseNum = aDecoder.decodeInteger(forKey: "PhaseNumber")
        
        self.init(coilName:coilName, coilRadialPosition:coilRadialPosition, amps:amps, currentDirection:currentDirection, capacitanceToPreviousCoil:capacitanceToPreviousCoil, capacitanceToGround:capacitanceToGround, innerRadius:innerRadius, eddyLossPercentage:eddyLossPercentage, phaseNum:phaseNum, sections:validSections)
    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.coilName, forKey: "CoilName")
        aCoder.encode(self.coilRadialPosition, forKey: "CoilRadialPosition")
        aCoder.encode(self.amps, forKey: "Amps")
        aCoder.encode(self.currentDirection, forKey: "CurrentDirection")
        aCoder.encode(self.capacitanceToPreviousCoil, forKey: "CapToPreviousCoil")
        aCoder.encode(self.capacitanceToGround, forKey: "CapToGround")
        aCoder.encode(self.innerRadius, forKey: "InnerRadius")
        aCoder.encode(self.eddyLossPercentage, forKey: "EddyLossPercentage")
        
        var validSections:[AxialSection] = []
        for nextSection in self.sections!
        {
            if nextSection.numDisks > 0
            {
                validSections.append(nextSection)
            }
        }
        
        aCoder.encode(validSections, forKey: "Sections")
        
        aCoder.encode(self.phaseNum, forKey: "PhaseNumber")
    }
    
    class func CoilUsing(xlFileCoil:ExcelDesignFile.CoilData, coilName:String, capacitanceToPreviousCoil:Double, capacitanceToGround:Double, eddyLossPercentage:Double, phaseNum:Int) -> Coil
    {
        return Coil(coilName: coilName, coilRadialPosition: 0, amps: 0.0, currentDirection: 0, capacitanceToPreviousCoil: capacitanceToPreviousCoil, capacitanceToGround: capacitanceToGround, innerRadius: 0.0, eddyLossPercentage: eddyLossPercentage, phaseNum: 0)
    }
    
    class func CapacitanceBetweenCoils(innerOD:Double, outerID:Double, innerH:Double, outerH:Double, numSpacers:Int) -> Double
    {
        // most variable names come from the Excel Impulse Distribution sheet
        
        let R_gap = (innerOD + outerID) / 4.0
        let H = (innerH + outerH) / 2.0
        let W_s = 0.75 * meterPerInch
        let N_s = Double(numSpacers)
        let f_s = N_s * W_s / (2.0 * π * R_gap)
        let N_press = floor(((outerID - innerOD) / 2.0) / 0.0084)
        let t_press = 0.08 * meterPerInch * N_press
        let t_stick = (outerID - innerOD) / 2.0 - t_press
        
        let result = 2.0 * π * ε0 * R_gap * H * ((f_s / (t_press / εBoard + t_stick / εBoard)) + ((1.0 - f_s) / (t_press / εBoard + t_stick / εOil)))
        
        return result
    }
    
    class func CapacitanceFromCoilToTank(coilOD:Double, coilHt:Double, tankDim:Double) -> Double
    {
        // we assume that there are two tubes of 1/8" over the finished coil
        
        let H = coilHt
        let s = tankDim / 2.0
        let t_solid = 2.0 * 0.125 * meterPerInch
        let t_oil = s - coilOD / 2.0 - t_solid
        
        let result = 2.0 * π * ε0 * H / acosh(s / (coilOD / 2.0)) * ((t_oil + t_solid) / ((t_oil / εOil) + (t_solid / εBoard)))
        
        return result
    }
    
    class func CapacitanceBetweenPhases(legCenters:Double, coilOD:Double, coilHt:Double) -> Double
    {
        // we assume that there are two tubes of 1/8" over EACH of the finished coils
        
        let H = coilHt
        let s = legCenters / 2.0
        let t_solid = 5 * 0.125 * meterPerInch // the '5' comes from the Excel design sheet
        let t_oil = legCenters - coilOD - t_solid
        
        let result = π * ε0 * H / acosh(s / (coilOD / 2.0)) * ((t_oil + t_solid) / ((t_oil / εOil) + (t_solid / εBoard)))
        
        return result
    }
    
    /// The actual number of axial sections (ie: the ones where numDisks is non-zero)
    var numAxialSections:Int {
        get
        {
            var result = 0
            
            if let sects = self.sections
            {
                for nextSection in sects
                {
                    if nextSection.numDisks > 0
                    {
                        result += 1
                    }
                }
            }
            
            return result
        }
    }
    
    /// The total number of disks in the coil
    var numDisks:Double {
        get
        {
            var result = 0.0
            if let sects = self.sections
            {
                for nextSection in sects
                {
                    result += nextSection.numDisks
                }
            }
            
            return result
        }
    }
    
    /// The total number of turns in the coil
    var turns:Double {
        get
        {
            var result = 0.0
            if let sects = self.sections
            {
                for nextSection in sects
                {
                    result += nextSection.turns
                }
            }
            
            return result
        }
    }
    
    /// The dimension of the bottom of the coil (assumes that the bottom yoke is at 0). Note that the core dimensions must be in the same units as the coil
    func CoilBottom(_ forWindowHt:Double, centerOffset:Double) -> Double
    {
        let result = forWindowHt / 2.0 + centerOffset - self.Height() / 2.0
        
        return result
    }
    
    func Height() -> Double
    {
        var result = 0.0
        
        if let axialSections = sections
        {
            for nextSection in axialSections
            {
                result += nextSection.Height()
            }
        }
        
        return result
    }
}

class AxialSection:NSObject, NSCoding
{
    /// sectionAxialPosition is relative to the bottom yoke: 0 is closest (lowest), 1 is next, etc.
    let sectionAxialPosition:Int
    
    /// The total number of turns in the section
    let turns:Double
    
    /// The number of disks that make up the section
    let numDisks:Double
    
    /// Capacitances
    let topDiskSerialCapacitance:Double
    let bottomDiskSerialCapacitance:Double
    let commonDiskSerialCapacitance:Double
    
    /// Static ring info (for drawing). It is assumed that the spacer between the disc and the static ring is equal to half the interDiskDimn
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
    
    /// Variable to decide if we need to consider intercoil capacitances and mutual inductances (ie: is this coil decoupled from the others?). For now, we use the simplification that the "main" coils are on phase 1, while any others are on phase 0 (if I ever need to fix this to allow for more than one other phase, this assumption will need to be modified)
    var phaseNum:Int
    
    init(sectionAxialPosition:Int, turns:Double, numDisks:Double, topDiskSerialCapacitance:Double, bottomDiskSerialCapacitance:Double, commonDiskSerialCapacitance:Double, topStaticRing:Bool, bottomStaticRing:Bool, isInterleaved:Bool, diskResistance:Double, diskSize:NSSize, interDiskDimn:Double, overTopDiskDimn:Double, phaseNum:Int)
    {
        self.sectionAxialPosition = sectionAxialPosition
        self.turns = turns
        self.numDisks = numDisks
        self.topDiskSerialCapacitance = topDiskSerialCapacitance
        self.bottomDiskSerialCapacitance = bottomDiskSerialCapacitance
        self.commonDiskSerialCapacitance = commonDiskSerialCapacitance
        self.topStaticRing = topStaticRing
        self.bottomStaticRing = bottomStaticRing
        self.isInterleaved = isInterleaved
        self.diskResistance = diskResistance
        self.diskSize = diskSize
        self.interDiskDimn = interDiskDimn
        self.overTopDiskDimn = overTopDiskDimn
        self.phaseNum = phaseNum
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        
        let sectionAxialPosition = aDecoder.decodeInteger(forKey: "AxialPosition")
        let turns = aDecoder.decodeDouble(forKey: "Turns")
        let numDisks = aDecoder.decodeDouble(forKey: "NumDisks")
        let topDiskSerialCapacitance = aDecoder.decodeDouble(forKey: "TopSerCap")
        let bottomDiskSerialCapacitance = aDecoder.decodeDouble(forKey: "BottomSerCap")
        let commonDiskSerialCapacitance = aDecoder.decodeDouble(forKey: "CommonSerCap")
        let topStaticRing = aDecoder.decodeBool(forKey: "TopStaticRing")
        let bottomStaticRing = aDecoder.decodeBool(forKey: "BottomStaticRing")
        let isInterleaved = aDecoder.decodeBool(forKey: "IsInterleaved")
        let diskResistance = aDecoder.decodeDouble(forKey: "DiskResistance")
        let diskSize = aDecoder.decodeSize(forKey: "DiskSize")
        let interDiskDimn = aDecoder.decodeDouble(forKey: "InterDiskDimn")
        let overTopDiskDimn = aDecoder.decodeDouble(forKey: "OverTopDiskDimn")
        let phaseNum = aDecoder.decodeInteger(forKey: "PhaseNumber")
        
        self.init(sectionAxialPosition:sectionAxialPosition, turns:turns, numDisks:numDisks, topDiskSerialCapacitance:topDiskSerialCapacitance, bottomDiskSerialCapacitance:bottomDiskSerialCapacitance, commonDiskSerialCapacitance:commonDiskSerialCapacitance, topStaticRing:topStaticRing, bottomStaticRing:bottomStaticRing, isInterleaved:isInterleaved, diskResistance:diskResistance, diskSize:diskSize, interDiskDimn:interDiskDimn, overTopDiskDimn:overTopDiskDimn, phaseNum:phaseNum)
    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.sectionAxialPosition, forKey: "AxialPosition")
        aCoder.encode(self.turns, forKey: "Turns")
        aCoder.encode(self.numDisks, forKey: "NumDisks")
        aCoder.encode(self.topDiskSerialCapacitance, forKey: "TopSerCap")
        aCoder.encode(self.bottomDiskSerialCapacitance, forKey: "BottomSerCap")
        aCoder.encode(self.commonDiskSerialCapacitance, forKey: "CommonSerCap")
        aCoder.encode(self.topStaticRing, forKey: "TopStaticRing")
        aCoder.encode(self.bottomStaticRing, forKey: "BottomStaticRing")
        aCoder.encode(self.isInterleaved, forKey: "IsInterleaved")
        aCoder.encode(self.diskResistance, forKey: "DiskResistance")
        aCoder.encode(self.diskSize, forKey: "DiskSize")
        aCoder.encode(self.interDiskDimn, forKey: "InterDiskDimn")
        aCoder.encode(self.overTopDiskDimn, forKey: "OverTopDiskDimn")
        aCoder.encode(self.phaseNum, forKey: "PhaseNumber")
    }
    
    func Height() -> Double
    {
        let result = Double(numDisks) * Double(diskSize.height) + Double(numDisks - 1) * interDiskDimn + overTopDiskDimn
        
        return result
    }
}
