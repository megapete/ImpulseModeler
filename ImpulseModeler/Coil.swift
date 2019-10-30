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
    var capacitanceToGround:Double

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
    
    // Dummy init
    override convenience init()
    {
        self.init(coilName: "", coilRadialPosition: 0, amps: 0.0, currentDirection: 0, capacitanceToPreviousCoil: 0.0, capacitanceToGround: 0.0, innerRadius: 0.0, eddyLossPercentage: 0.0, phaseNum: 0)
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
    
    class func CoilUsing(xlFileCoil:ExcelDesignFile.CoilData, coilName:String, coilPosition:Int, connection:String, amps:Double, currentDirection:Int, capacitanceToPreviousCoil:Double, capacitanceToGround:Double, eddyLossPercentage:Double, phaseNum:Int) -> Coil
    {
        // take care of the 'simple' case where the coil is a helix, layer, or sheet winding (any time numAxialSections <= 2)
        // TODO: Develop a better method to represent helix, layer, and sheet windings
        let isSheet = !xlFileCoil.isHelical && !xlFileCoil.isMultipleStart && xlFileCoil.numAxialSections <= 2
        if xlFileCoil.isHelical || xlFileCoil.isMultipleStart || (xlFileCoil.numAxialSections <= 2)
        {
            // choose a sufficiently low number for series capacitance - ultimately, I don't think this will matter anyway for a single coil section
            var seriesCap = 1.0E-12
            
            // for now, we'll only consider the series capacitance of the turns for sheet windings (again, not that it makes a difference)
            if isSheet
            {
                let turnCap = CapacitanceBetweenTurns(turnLength: xlFileCoil.lmt, condW: xlFileCoil.strandA * Double(xlFileCoil.numAxialSections), paperBetweenTurns: xlFileCoil.totalPaperThicknessInOneTurnRadially)
                
                seriesCap = CapacitanceOfDiskTurns(capBetweenTurns: turnCap, numTurns: xlFileCoil.maxTurns)
            }
            
            let coilResistance = ResistanceCu20(conductorArea: xlFileCoil.condAreaPerTurn, length: xlFileCoil.maxTurns * xlFileCoil.lmt)
            let coilSize = NSSize(width: xlFileCoil.radialBuild, height: xlFileCoil.elecHt)
            
            let axialSection = AxialSection(sectionAxialPosition: 0, turns: xlFileCoil.maxTurns, numDisks: 1, topDiskSerialCapacitance: seriesCap, bottomDiskSerialCapacitance: seriesCap, commonDiskSerialCapacitance: seriesCap, topStaticRing: false, bottomStaticRing: false, isInterleaved: false, diskResistance: coilResistance, diskSize: coilSize, interDiskDimn: 0.0, overTopDiskDimn: 0.0, phaseNum: 1)
            
            return Coil(coilName: coilName, coilRadialPosition: coilPosition, amps: amps, currentDirection: currentDirection, capacitanceToPreviousCoil: capacitanceToPreviousCoil, capacitanceToGround: capacitanceToGround, innerRadius: xlFileCoil.coilID / 2.0, eddyLossPercentage: eddyLossPercentage, phaseNum: 1, sections: [axialSection])
        }
        
        // It must be a disk coil, so throw up the Coil Details dialog box to get static/winding ring & interleave data
        let detailsDbox = GetCoilDetailsDlogBox(coilName: coilName)
        
        // disk coils can only be regulating windings if they are "double-stack"
        detailsDbox.regulatingWdg.isEnabled = xlFileCoil.isDoubleStack
        
        // TODO: Implement in-coil winding rings (if really necessary)
        detailsDbox.windingRing.isEnabled = false
        
        let _ = detailsDbox.runModal()
        
        let lineAtTop = detailsDbox.lineAtTop.state == .on
        let lineAtCenter = detailsDbox.lineAtCenter.state == .on
        let regWdg = detailsDbox.regulatingWdg.state == .on
        
        let staticRingAtTop = detailsDbox.topStaticRing.state == .on
        let staticRingAtCenter = detailsDbox.centerStaticRing.state == .on
        let staticRingAtBottom = detailsDbox.bottomStaticRing.state == .on
        
        // Per-disk data
        let turnsPerDisk = xlFileCoil.maxTurns / xlFileCoil.numAxialSections
        let numStdGaps = xlFileCoil.numAxialSections - 1.0 - (xlFileCoil.axialCenterPack > 0.001 ? 1.0 : 0.0) - (xlFileCoil.axialDVgap1 > 0.001 ? 1.0 : 0.0) - (xlFileCoil.axialDVgap2 > 0.001 ? 1.0 : 0.0)
        let totalAxialGapsDimn = (numStdGaps * xlFileCoil.axialGaps + xlFileCoil.axialCenterPack + xlFileCoil.axialDVgap1 + xlFileCoil.axialDVgap2) * 0.98
        let diskAxialDimn = (xlFileCoil.elecHt - totalAxialGapsDimn) / xlFileCoil.numAxialSections
        let diskSize = NSSize(width: xlFileCoil.radialBuild, height: diskAxialDimn)
        let diskResistance = ResistanceCu20(conductorArea: xlFileCoil.condAreaPerTurn, length: turnsPerDisk * xlFileCoil.lmt)
        let turnCap = CapacitanceBetweenTurns(turnLength: xlFileCoil.lmt, condW: diskAxialDimn, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
        let diskTurnsCap = CapacitanceOfDiskTurns(capBetweenTurns: turnCap, numTurns: turnsPerDisk)
        let interleavedDiscTurnsCap = InterleavedPairTurnsCapacitance(turnToTurnCap: turnCap, turnsPerDisk: turnsPerDisk)
        let Fks = KeySpacerFactor(numColumns: xlFileCoil.numAxialColumns, spacerW: xlFileCoil.axialSpacerWidth, lmt: xlFileCoil.lmt)
        let capBetweenDisks = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: xlFileCoil.axialGaps, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
        
        let capToStaticRing = (staticRingAtTop || staticRingAtCenter || staticRingAtTop ? CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: xlFileCoil.axialGaps / 2.0, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn / 2.0) : 0.0)
        
        // Static-ring dimensional data
        let ringAxialGap = xlFileCoil.axialGaps / 2.0
        let endRingAxialDimn = meters(inches: 0.625) + ringAxialGap * 0.98
        let wdgRingAxialDimn = meters(inches: 0.625) + 2.0 * ringAxialGap * 0.98
        
        let isDelta = connection == "D"
        let isDoubleStack = xlFileCoil.isDoubleStack
        let isInterleaved = detailsDbox.noInterleave.state == .off
        
        let totalSections = Int(xlFileCoil.numAxialSections)
        var boundsSet:Set<Int> = [0, totalSections - 1]
        
        var arbitraryStarts:Set<Int> = []
        var aribitraryEnds:Set<Int> = []
        
        // handle interleaving
        var interleavedRange:[Range<Int>] = []
        
        if isInterleaved
        {
            if detailsDbox.fullInterleave.state == .on
            {
                let intRange = 0..<totalSections
                interleavedRange = [intRange]
            }
            else
            {
                if let partialDisks = Int(detailsDbox.numPartialDisks.stringValue)
                {
                    if isDelta
                    {
                        interleavedRange = [0..<partialDisks, (totalSections - partialDisks)..<totalSections]
                        boundsSet.insert(partialDisks - 1)
                        arbitraryStarts.insert(partialDisks)
                        boundsSet.insert(totalSections - partialDisks)
                        aribitraryEnds.insert(totalSections - partialDisks - 1)
                    }
                    else if isDoubleStack && lineAtCenter
                    {
                        let midpoint = totalSections / 2
                        interleavedRange = [(midpoint - partialDisks)..<(midpoint + partialDisks)]
                        boundsSet.insert(midpoint - partialDisks)
                        aribitraryEnds.insert(midpoint - partialDisks - 1)
                        boundsSet.insert(midpoint + partialDisks - 1)
                        arbitraryStarts.insert(midpoint + partialDisks)
                    }
                    else
                    {
                        interleavedRange = [(totalSections - partialDisks)..<totalSections]
                        boundsSet.insert(totalSections - partialDisks)
                        aribitraryEnds.insert(totalSections - partialDisks - 1)
                    }
                }
            }
        }
        
        let mainRange:[Range<Int>] = (isDoubleStack ? [0..<(totalSections / 2), (totalSections / 2)..<totalSections] : [0..<totalSections])
        if isDoubleStack
        {
            boundsSet.insert(totalSections / 2 - 1)
            boundsSet.insert(totalSections / 2)
        }
        
        let hasTaps = xlFileCoil.nomTurns != xlFileCoil.maxTurns
        var minorRange:[Range<Int>] = []
        
        // assume that anything less than 7/8" is for a static ring (ie: center-fed winding)
        if xlFileCoil.axialCenterPack > meters(inches: 0.875)
        {
            let mainLower = 0
            let halfWay = totalSections / 2
            
            minorRange = [mainLower..<halfWay, halfWay..<totalSections]
        }
        
        // Take care of gaps that are in the winding for matching gaps in other windings
        if xlFileCoil.axialDVgap1 > 0.001
        {
            let mainLower = 0
            let halfWayMain = totalSections / 2
            let gapLoc = halfWayMain / 2
            
            minorRange.append(mainLower..<gapLoc)
            minorRange.append(gapLoc..<halfWayMain)
            arbitraryStarts.insert(halfWayMain)
        }
        
        if xlFileCoil.axialDVgap2 > 0.001
        {
            let halfWayMain = totalSections / 2
            let gapLoc = halfWayMain * 3 / 2
            
            aribitraryEnds.insert(halfWayMain - 1)
            minorRange.append(halfWayMain..<gapLoc)
            minorRange.append(gapLoc..<totalSections)
        }
        
        var tapRange:[Range<Int>] = []
        if hasTaps
        {
            let tapTurns = xlFileCoil.maxTurns - xlFileCoil.minTurns
            let tapSectionDisksExact = tapTurns / turnsPerDisk / 2.0
            var tapSectionDisks = Int(round(tapSectionDisksExact))
            
            if !xlFileCoil.isDoubleStack
            {
                let mainLower = mainRange[0].lowerBound
                let halfWay = mainRange[0].upperBound / 2
                
                minorRange = [mainLower..<halfWay, halfWay..<totalSections]
                tapRange = [halfWay - tapSectionDisks..<halfWay, halfWay..<halfWay + tapSectionDisks]
                aribitraryEnds.insert(halfWay - tapSectionDisks - 1)
                boundsSet.insert(halfWay - tapSectionDisks)
                boundsSet.insert(halfWay - 1)
                boundsSet.insert(halfWay)
                boundsSet.insert(halfWay + tapSectionDisks - 1)
                arbitraryStarts.insert(halfWay + tapSectionDisks)
            }
            else
            {
                let mainLower1 = mainRange[0].lowerBound
                let halfWay1 = mainRange[0].upperBound / 2
                let mainMiddle = mainRange[0].upperBound
                let halfWay2 = mainMiddle + halfWay1
                
                minorRange = [mainLower1..<halfWay1, halfWay1..<mainMiddle, mainMiddle..<halfWay2, halfWay2..<totalSections]
                
                tapSectionDisks = Int(round(tapSectionDisksExact / 2.0))
                tapRange = [halfWay1 - tapSectionDisks..<halfWay1, halfWay1..<halfWay1 + tapSectionDisks, halfWay2 - tapSectionDisks..<halfWay2, halfWay2..<halfWay2 + tapSectionDisks]
                
                aribitraryEnds.insert(halfWay1 - tapSectionDisks - 1)
                arbitraryStarts.insert(halfWay1 + tapSectionDisks)
                aribitraryEnds.insert(halfWay2 - tapSectionDisks - 1)
                arbitraryStarts.insert(halfWay2 + tapSectionDisks)
                
                for nextRange in minorRange
                {
                    boundsSet.insert(nextRange.lowerBound)
                    boundsSet.insert(nextRange.upperBound - 1)
                }
                for nextRange in tapRange
                {
                    boundsSet.insert(nextRange.lowerBound)
                    boundsSet.insert(nextRange.upperBound - 1)
                }
            }
        }
        
        if !arbitraryStarts.intersection(aribitraryEnds).isEmpty
        {
            ALog("Index is at start and end!")
        }
        
        boundsSet.formUnion(arbitraryStarts)
        boundsSet.formUnion(aribitraryEnds)
        
        var axialSections:[AxialSection] = []
        var currentAxialPosition = 0
        var currentCumTurns = 0.0
        var currentCumDisks = 0
        var hasBottomStaticRing = false
        
        var bottomSeriesCap = 0.0
        var commonSeriesCap = 0.0
        var topSeriesCap = 0.0
        
        for diskIndex in 0..<totalSections
        {
            currentCumDisks += 1
            currentCumTurns += turnsPerDisk
            
            // first check if this disk is one of our bounds
            if boundsSet.contains(diskIndex)
            {
                let mainMemberType = CheckForBound(rangeArray: mainRange, boundToCheck: diskIndex)
                let minorMemberType = CheckForBound(rangeArray: minorRange, boundToCheck: diskIndex)
                let tapMemberType = CheckForBound(rangeArray: tapRange, boundToCheck: diskIndex)
                let interleavedMemberType = CheckForBound(rangeArray: interleavedRange, boundToCheck: diskIndex)
                
                // Now go through all the possibilities
                if mainMemberType == .FirstBound
                {
                    // This is either the lowest disk or the the first line disk at center
                    
                    let staticRingBelow = (diskIndex == 0 ? staticRingAtBottom : staticRingAtCenter)
                    hasBottomStaticRing = staticRingBelow
                    
                    if interleavedMemberType != .NotAMember
                    {
                        if staticRingBelow
                        {
                            bottomSeriesCap = InterleavedEndDiskWithStaticRingCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            bottomSeriesCap = InterleavedTerminalDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks)
                        }
                        
                        commonSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        if staticRingBelow
                        {
                            bottomSeriesCap = EndDiskWithStaticRingCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            bottomSeriesCap = TerminalDiskCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks)
                        }
                        
                        commonSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                }
                else if minorMemberType == .FirstBound && tapMemberType == .FirstBound
                {
                    // This is the first disk after a tapping break (either offload or delta-connected onload)
                    let underGap = (isDoubleStack ? xlFileCoil.axialDVgap1 : xlFileCoil.axialCenterPack)
                    let capToDiskBelow = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: underGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                    
                    if interleavedMemberType != .NotAMember
                    {
                        bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                        
                        commonSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        bottomSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                        
                        commonSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                }
                else if minorMemberType != .FirstBound && tapMemberType == .FirstBound
                {
                    // This is the first disk of a tapping section within the winding (not after a tapping break)
                    if interleavedMemberType != .NotAMember
                    {
                        bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        bottomSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    
                    commonSeriesCap = bottomSeriesCap
                }
                else if minorMemberType == .FirstBound && (diskIndex != totalSections / 2)
                {
                    // This is the first disk after the gap that is used to match the gap(s) in another winding
                    let underGap = (diskIndex < totalSections / 2 ? xlFileCoil.axialDVgap1 : xlFileCoil.axialDVgap2)
                    let capToDiskBelow = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: underGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                    
                    if interleavedMemberType != .NotAMember
                    {
                        bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                        
                        commonSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        bottomSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                        
                        commonSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    
                }
                else if minorMemberType == .FirstBound
                {
                    // This is the first disk after the gap for a delta-connected LTC or a split regulating winding
                    if staticRingAtCenter
                    {
                        if interleavedMemberType != .NotAMember
                        {
                            bottomSeriesCap = InterleavedEndDiskWithStaticRingCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                            
                            commonSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                        }
                        else
                        {
                            bottomSeriesCap = EndDiskWithStaticRingCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                            
                            commonSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                        }
                        
                        hasBottomStaticRing = true
                    }
                    else
                    {
                        let underGap = xlFileCoil.axialCenterPack
                        let capToDiskBelow = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: underGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                    
                        if interleavedMemberType != .NotAMember
                        {
                            bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                            
                            commonSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                        }
                        else
                        {
                            bottomSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capToDiskBelow)
                            
                            commonSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                        }
                    }
                    
                }
                else if interleavedMemberType == .FirstBound
                {
                    // This is the first disk of an interleaved section
                    bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    
                    commonSeriesCap = bottomSeriesCap
                }
                else if mainMemberType == .LastBound
                {
                    // This is either the final disk or the last disk before the center-line lead
                    let staticRingAbove = (diskIndex == totalSections - 1 ? staticRingAtTop : staticRingAtCenter)
                    
                    if interleavedMemberType != .NotAMember
                    {
                        if staticRingAbove
                        {
                            topSeriesCap = InterleavedEndDiskWithStaticRingCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            topSeriesCap = InterleavedTerminalDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks)
                        }
                    }
                    else
                    {
                        if staticRingAbove
                        {
                            topSeriesCap = EndDiskWithStaticRingCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            topSeriesCap = TerminalDiskCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks)
                        }
                    }
                    
                    let overTopDimn = (diskIndex == totalSections - 1 ? 0.0 : xlFileCoil.axialCenterPack)
                    
                    // add axial section
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: staticRingAbove, bottomStaticRing: hasBottomStaticRing, isInterleaved: interleavedMemberType != .NotAMember, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: overTopDimn, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    // set/reset variables for next disk
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if minorMemberType == .LastBound && tapMemberType == .LastBound
                {
                    // This is the last disk of a tapping section before a tapping break
                    let overGap = (isDoubleStack ? xlFileCoil.axialDVgap1 : xlFileCoil.axialCenterPack)
                    let capToDiskAbove = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: overGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                    
                    if interleavedMemberType != .NotAMember
                    {
                        topSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capToDiskAbove, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        topSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capToDiskAbove, capToDiskBelow: capBetweenDisks)
                    }
                    
                    // add axial section
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: false, bottomStaticRing: hasBottomStaticRing, isInterleaved: interleavedMemberType != .NotAMember, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: overGap, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if minorMemberType != .LastBound && tapMemberType == .LastBound
                {
                    // This is the last disk fo a tapping section within the winding
                    topSeriesCap = commonSeriesCap
                    
                    // add axial section
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: false, bottomStaticRing: hasBottomStaticRing, isInterleaved: interleavedMemberType != .NotAMember, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: xlFileCoil.axialGaps, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if minorMemberType == .LastBound
                {
                    // This is the last disk before the gap of delta-connected onload taps or a regulating winding, OR the final disk before the gap that is used to match the gap(s) in another winding
                    let staticRingAbove = (diskIndex == totalSections / 2 - 1 ? staticRingAtCenter : false)
                    let overTopDimn = (diskIndex == totalSections / 2 - 1 ? xlFileCoil.axialCenterPack : (diskIndex < totalSections / 2 - 1 ? xlFileCoil.axialDVgap1 : xlFileCoil.axialDVgap2))
                    
                    if interleavedMemberType != .NotAMember
                    {
                        if staticRingAbove
                        {
                            topSeriesCap = InterleavedEndDiskWithStaticRingCapacitance(turnsCap: interleavedDiscTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            let overGap = overTopDimn
                            let capToDiskAbove = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: overGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                            
                            topSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capToDiskAbove, capToDiskBelow: capBetweenDisks)
                        }
                    }
                    else
                    {
                        if staticRingAbove
                        {
                            topSeriesCap = EndDiskWithStaticRingCapacitance(turnsCap: diskTurnsCap, capToOtherDisk: capBetweenDisks, capToStaticRing: capToStaticRing)
                        }
                        else
                        {
                            let overGap = overTopDimn
                            let capToDiskAbove = CapacitanceBetweenDisks(diskID: xlFileCoil.coilID, diskOD: xlFileCoil.coilOD, keySpacerT: overGap, keySpacerFactor: Fks, paperBetweenTurns: xlFileCoil.paperOverOneTurn)
                            topSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capToDiskAbove, capToDiskBelow: capBetweenDisks)
                        }
                    }
                    
                    // add axial section
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: staticRingAbove, bottomStaticRing: hasBottomStaticRing, isInterleaved: interleavedMemberType != .NotAMember, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: overTopDimn, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    // set/reset variables for next disk
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if interleavedMemberType == .LastBound
                {
                    topSeriesCap = commonSeriesCap
                    // add axial section
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: false, bottomStaticRing: false, isInterleaved: true, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: xlFileCoil.axialGaps, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    // set/reset variables for next disk
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if aribitraryEnds.contains(diskIndex)
                {
                    topSeriesCap = commonSeriesCap
                    
                    let newAxialSection = AxialSection(sectionAxialPosition: currentAxialPosition, turns: currentCumTurns, numDisks: Double(currentCumDisks), topDiskSerialCapacitance: topSeriesCap, bottomDiskSerialCapacitance: bottomSeriesCap, commonDiskSerialCapacitance: commonSeriesCap, topStaticRing: false, bottomStaticRing: false, isInterleaved: interleavedMemberType != .NotAMember, diskResistance: diskResistance, diskSize: diskSize, interDiskDimn: xlFileCoil.axialGaps, overTopDiskDimn: xlFileCoil.axialGaps, phaseNum: 1)
                    
                    axialSections.append(newAxialSection)
                    
                    // set/reset variables for next disk
                    currentAxialPosition += 1
                    currentCumTurns = 0
                    currentCumDisks = 0
                    hasBottomStaticRing = false
                }
                else if arbitraryStarts.contains(diskIndex)
                {
                    if interleavedMemberType != .NotAMember
                    {
                        bottomSeriesCap = InterleavedCommonDiskCapacitance(turnsCap: interleavedDiscTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    else
                    {
                        bottomSeriesCap = CommonDiskCapacitance(turnsCap: diskTurnsCap, capToDiskAbove: capBetweenDisks, capToDiskBelow: capBetweenDisks)
                    }
                    
                    commonSeriesCap = bottomSeriesCap
                }
                else
                {
                    ALog("Unimplemented arrangement!!!")
                }
            }
        }
        
        return Coil(coilName: coilName, coilRadialPosition: coilPosition, amps: amps, currentDirection: currentDirection, capacitanceToPreviousCoil: capacitanceToPreviousCoil, capacitanceToGround: capacitanceToGround, innerRadius: xlFileCoil.coilID / 2.0, eddyLossPercentage: eddyLossPercentage, phaseNum: 1, sections: axialSections)
    }
    
    // Return types for the CheckForBound function (below)
    enum RangeBoundMemberType
    {
        case NotAMember
        case FirstBound
        case LastBound
        case ContainsBound
    }
    
    fileprivate class func CheckForBound(rangeArray:[Range<Int>], boundToCheck:Int) -> RangeBoundMemberType
    {
        for nextRange in rangeArray
        {
            if nextRange.contains(boundToCheck)
            {
                if boundToCheck == nextRange.lowerBound
                {
                    return .FirstBound
                }
                
                if boundToCheck == nextRange.upperBound - 1
                {
                    return .LastBound
                }
                
                return .ContainsBound
            }
        }
        
        return .NotAMember
    }
    
    /// This function assumes that 'turnsCap' is for a "disk-pair". It then uses the the EndDiskWithStaticRingCapacitance function as though the double-disk is actually a single. Finally, it multiplies the resultant capacitance by 2 to get an "effective" capacitances (this sorta makes sense to me since the static ring _is_ facing the interleave).
    class func InterleavedEndDiskWithStaticRingCapacitance(turnsCap:Double, capToOtherDisk:Double, capToStaticRing:Double) -> Double
    {
        let pairCap = EndDiskWithStaticRingCapacitance(turnsCap: turnsCap, capToOtherDisk: capToOtherDisk, capToStaticRing: capToStaticRing)
        
        return pairCap * 2.0
    }
    
    /// This function assumes that 'turnsCap' is for a "disk-pair". It then uses the standard method to calculate the series capacitance of the pair as if it was a single disk. Finally, it multiplies that calculated capacitance by 2 to get an "effective per-disk capacitance".
    class func InterleavedCommonDiskCapacitance(turnsCap:Double, capToDiskAbove:Double, capToDiskBelow:Double) -> Double
    {
        let pairCap = CommonDiskCapacitance(turnsCap: turnsCap, capToDiskAbove: capToDiskAbove, capToDiskBelow: capToDiskBelow)
        
        return pairCap * 2.0
    }
    
    // See the description above for other Interleaved calculations to see where I came up with the logic for this function.
    /// This function assumes that 'turnsCap' is for a "disk-pair".
    class func InterleavedTerminalDiskCapacitance(turnsCap:Double, capToOtherDisk:Double) -> Double
    {
        let pairCap = TerminalDiskCapacitance(turnsCap: turnsCap, capToOtherDisk: capToOtherDisk)
        
        return pairCap * 2.0
    }
    
    class func InterleavedPairTurnsCapacitance(turnToTurnCap:Double, turnsPerDisk:Double) -> Double
    {
        return turnToTurnCap * (turnsPerDisk - 1) / 2.0
    }
    
    class func TerminalDiskCapacitance(turnsCap:Double, capToOtherDisk:Double) -> Double
    {
        let alpha = sqrt(2.0 * capToOtherDisk / turnsCap)
        
        return turnsCap * alpha / tanh(alpha)
    }
    
    class func EndDiskWithStaticRingCapacitance(turnsCap:Double, capToOtherDisk:Double, capToStaticRing:Double) -> Double
    {
        let Ya = capToStaticRing / (capToStaticRing + 2.0 * capToOtherDisk)
        let Yb = 2.0 * capToOtherDisk / (capToStaticRing + 2.0 * capToOtherDisk)
        let alpha = sqrt((capToStaticRing + 2.0 * capToOtherDisk) / turnsCap)
        
        return GeneralDiskSeriesCapacitance(Cs: turnsCap, Ya: Ya, Yb: Yb, alpha: alpha)
    }
    
    class func CommonDiskCapacitance(turnsCap:Double, capToDiskAbove:Double, capToDiskBelow:Double) -> Double
    {
        let Ya = capToDiskAbove / (capToDiskAbove + capToDiskBelow)
        let Yb = capToDiskBelow / (capToDiskAbove + capToDiskBelow)
        let alpha = sqrt(2.0 * (capToDiskAbove + capToDiskBelow) / turnsCap)
        
        return GeneralDiskSeriesCapacitance(Cs: turnsCap, Ya: Ya, Yb: Yb, alpha: alpha)
    }
    
    /// From DelVecchio Ed.2 Section 12.4, Formula 12.53
    class func GeneralDiskSeriesCapacitance(Cs:Double, Ya:Double, Yb:Double, alpha:Double) -> Double
    {
        let result = Cs * ((Ya * Ya + Yb * Yb) * alpha / tanh(alpha) + 2.0 * Ya * Yb * alpha / sinh(alpha) + Ya * Yb * alpha * alpha)
        
        return result
    }
    
    class func CapacitanceBetweenDisks(diskID:Double, diskOD:Double, keySpacerT:Double, keySpacerFactor:Double, paperBetweenTurns:Double) -> Double
    {
        let rIn = diskID / 2.0
        let rOut = diskOD / 2.0
        
        let fSpacer = keySpacerFactor / (paperBetweenTurns / εPaper + keySpacerT / εBoard)
        let fOil = (1.0 - keySpacerFactor) / (paperBetweenTurns / εPaper + keySpacerT / εOil)
        
        let result = ε0 * π * (rOut * rOut - rIn * rIn) * (fSpacer + fOil)
        
        return result
    }
    
    class func KeySpacerFactor(numColumns:Double, spacerW:Double, lmt:Double) -> Double
    {
        let result = numColumns * spacerW / lmt
        
        return result
    }
    
    class func CapacitanceOfDiskTurns(capBetweenTurns:Double, numTurns:Double) -> Double
    {
        let result = capBetweenTurns * (numTurns - 1.0) / (numTurns * numTurns)
        
        return result
    }
    
    class func CapacitanceBetweenTurns(turnLength:Double, condW:Double, paperBetweenTurns:Double) -> Double
    {
        let result = ε0 * εPaper * turnLength * (condW + 2.0 * paperBetweenTurns) / paperBetweenTurns
        
        return result
    }
    
    /// Resistance of copper conductor at 20C
    class func ResistanceCu20(conductorArea:Double, length:Double) -> Double
    {
        return 1.68e-8 * length / conductorArea
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
