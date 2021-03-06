//
//  ExcelDesignFile.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2019-10-17.
//  Copyright © 2019 Peter Huber. All rights reserved.
//

// This is intended to be a portable class that can be used by any Swift program to get at the data passed by the Excel desig file to the AndersenFE program. There are also a number of functions to "massage" the raw data. All data is converted from inches to meters before storing.

import Foundation
import Cocoa

class ExcelDesignFile: NSObject
{
    struct CoilData
    {
        var minTurns:Double = 0.0
        var nomTurns:Double = 0.0
        var maxTurns:Double = 0.0
        
        var elecHt:Double = 0.0
        
        var isHelical:Bool = false
        var isDoubleStack:Bool = false
        var isMultipleStart:Bool = false
        
        var numAxialSections:Double = 0.0
        var axialGaps:Double = 0.0
        var axialSpacerWidth:Double = 0.0
        var numAxialColumns:Double = 0.0
        
        var numRadialSections:Double = 0.0
        var insulationBetRadialSections:Double = 0.0
        var numRadialDucts:Double = 0.0
        var radialDuctDimn:Double = 0.0
        var numRadialColumns:Double = 0.0
        
        var condType:String = ""
        var numCondAxial:Int = 0
        var numCondRadial:Int = 0
        var condShape:String = "RECT"
        var totalPaperThicknessInOneTurnRadially:Double = 0.0
        
        var axialGapBetweenCables:Double = 0.0
        
        var strandA:Double = 0.0
        var strandR:Double = 0.0
        
        var ctcStrandsPerCable:Double = 1.0
        
        var axialCenterPack:Double = 0.0
        var axialDVgap1:Double = 0.0
        var axialDVgap2:Double = 0.0
        
        var bottomEdgeDistance:Double = 0.0
        
        var coilID:Double = 0.0
        
        var groundClearance:Double = 0.0
        
        var eddyLossAvePU = 0.1
        
        var overbuildAllowance = 1.06
        
        var paperOverOneTurn:Double {
            get
            {
                let doublePaperPerStrand = meters(inches: 0.012)
                
                var result = self.totalPaperThicknessInOneTurnRadially / Double(self.numCondRadial)
                if self.condType == "D"
                {
                    result -= Double(self.numCondRadial) * doublePaperPerStrand
                }
                
                return result
            }
        }
        
        var effectiveHt:Double {
            get
            {
                return self.elecHt - (self.axialCenterPack + self.axialDVgap1 + self.axialDVgap2) * 0.98
            }
        }
        
        /// This property returns the "rounded-up" number of radial strands per CTC cable
        var radialStrandsPerTurn:Double {
            get
            {
                if self.condType == "CTC"
                {
                    return ceil(self.ctcStrandsPerCable / 2.0) * Double(numCondRadial)
                }
                else if self.condType == "D"
                {
                    return 2.0 * Double(numCondRadial)
                }
                else
                {
                    return 1.0 * Double(numCondRadial)
                }
            }
        }
        
        var axialStrandsPerTurn:Double {
            get
            {
                var result = Double(numCondAxial)
                
                if self.condType == "CTC"
                {
                    result *= 2.0
                }
                
                return result
            }
        }
        
        var strandsPerTurn:Double {
            get
            {
                return self.axialStrandsPerTurn * self.radialStrandsPerTurn
            }
        }
        
        var condAreaPerTurn:Double {
            get
            {
                return strandR * strandA * self.strandsPerTurn
            }
        }
        
        var numTurnsRadially:Double {
            get
            {
                if self.isHelical || self.isMultipleStart
                {
                    return self.numRadialSections
                }
                else if self.numAxialSections <= 2 // sheet winding
                {
                    return self.maxTurns
                }
                
                return ceil(self.maxTurns / self.numAxialSections)
            }
        }
        
        var radialBuild:Double {
            get
            {
                var result = (self.numTurnsRadially * (self.radialStrandsPerTurn * (self.strandR + (self.condType == "CTC" ? meters(inches:0.0045) : 0.0)) + self.totalPaperThicknessInOneTurnRadially) + self.numRadialDucts * self.radialDuctDimn) * self.overbuildAllowance
                
                if self.isHelical || self.isMultipleStart
                {
                    let numInsuls = self.numTurnsRadially - 1.0 - self.numRadialDucts
                    result += numInsuls * self.insulationBetRadialSections
                }
                
                return result
            }
        }
        
        var coilOD:Double {
            get
            {
                return self.coilID + 2.0 * self.radialBuild
            }
        }
        
        var lmt:Double {
            get
            {
                return (self.coilID + self.radialBuild) * π
            }
        }
    }
    
    struct TerminalData
    {
        let lineVolts:Double
        let kVA:Double // will already be divided by the number of phases
        let connection:String
        let termNum:Int
        let currentDirection:Int
        
        var coilIndex:Int = 100 // put a large number here to make sorting easier
        
        var phaseVolts:Double {
            
            get
            {
                if self.coilIndex < 0
                {
                    return 0.0
                }
                
                return self.lineVolts / (self.connection == "Y" ? SQRT3 : 1.0)
            }
        }
        
        var phaseAmps:Double {
            
            get
            {
                if self.coilIndex < 0
                {
                    return 0.0
                }
                
                return self.kVA * 1000.0 / self.phaseVolts
            }
        }
    }
    
    // General Info
    let numPhases:Int
    
    let frequency:Double // Hertz
    
    let tempRise:Double // °C
    
    let onaf1:Double // percent of onan
    let onaf2:Double
    
    let coreDiameter:Double
    let windowHt:Double
    let legCenters:Double
    
    let tankDepth:Double
    
    let overbuildAllowance:Double
    
    let scFactor:Double
    let systemGVA:Double

    var terminals:[TerminalData] = []
    var coils:[CoilData] = Array(repeating: CoilData(), count: 8)
    
    var numCoils:Int {
        get
        {
            var result = 0
            
            for nextTerm in terminals
            {
                if nextTerm.coilIndex < 9
                {
                    result += 1
                }
            }
            
            return result
        }
    }
    
    struct DesignFileError:Error
    {
        enum errorType
        {
            case InvalidDesignFile
            case InvalidNumber
            case InvalidFileVersion
        }
        
        let info:String
        let type:DesignFileError.errorType
        
        var localizedDescription: String
        {
            get
            {
                if self.type == .InvalidDesignFile
                {
                    return "This is not a valid design file!"
                }
                else if self.type == .InvalidNumber
                {
                    return "An invalid number was found: " + self.info
                }
                else if self.type == .InvalidFileVersion
                {
                    return "The lowest acceptable file version is 3. This is version: " + self.info
                }
                
                return "An unknown error has occurred"
            }
        }
    }
    
    init(withURL file:URL) throws
    {
        var fileString = ""
        
        do
        {
            try fileString = String(contentsOf: file)
        }
        catch
        {
            throw error
        }
        
        let fileLines = fileString.components(separatedBy: .newlines).filter({$0 != ""})
        
        var currentIndex = 0
        
        // early checks to see if this is a valid design file
        if fileLines.count < 46 // design file version 3 has at least 46 lines
        {
            let error = DesignFileError(info: "\(fileLines.count)", type: .InvalidFileVersion)
            throw error
        }
        
        var currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        if currentLine.count != 8
        {
            let error = DesignFileError(info: "", type: .InvalidDesignFile)
            throw error
        }
        
        // for now, we only accept file version 3 and higher
        let fileVersion = Int(currentLine[7])
        if fileVersion == nil
        {
            let error = DesignFileError(info: "", type: .InvalidDesignFile)
            throw error
        }
        else if fileVersion! < 3
        {
            let error = DesignFileError(info: currentLine[7], type: .InvalidFileVersion)
            throw error
        }
        
        // version 3 and less of the Excel file is all in inches and we want meters, so:
        let convFactor = meterPerInch
        
        var index = 0
        guard let nPhases = Int(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad Num Phases:" + currentLine[index], type: .InvalidNumber)
            throw error
            
        }
        
        self.numPhases = nPhases
        
        index += 1
        guard let freq = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad frequency:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.frequency = freq
        
        index += 1
        guard let tRise = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad Temp Rise:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.tempRise = tRise
        
        index += 1
        guard let fans1 = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad ONAF1:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.onaf1 = fans1
        
        index += 1
        guard let fans2 = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad ONAF2:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.onaf2 = fans2
        
        index += 1
        guard let coreDia = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad Core Diameter:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.coreDiameter = coreDia * convFactor
        
        index += 1
        guard let windHt = Double(currentLine[index]) else
        {
            let error = DesignFileError(info: "Bad Window Height:" + currentLine[index], type: .InvalidNumber)
            throw error
        }
        
        self.windowHt = windHt * convFactor
        
        // If we got to here, we'll assume that this is a valid Excel design file and stop checking things so closely
        currentIndex += 1
        
        // There are 8 rows of terminal data
        for termOffset in 0..<8
        {
            let nextTermLine = fileLines[currentIndex + termOffset].components(separatedBy: .whitespaces)
            
            let nextTerm = TerminalData(lineVolts: Double(nextTermLine[0])!, kVA: Double(nextTermLine[1])! / Double(self.numPhases), connection: nextTermLine[2], termNum: Int(nextTermLine[3])!, currentDirection: Int(nextTermLine[4])!)
            
            self.terminals.append(nextTerm)
        }
        currentIndex += 8
        
        // The next line is the mapping of each terminal to its corresponding coil
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        for i in 0..<8
        {
            let nextMapping = currentLine[i]
            
            if let coilPos = Int(nextMapping)
            {
                self.terminals[i].coilIndex = coilPos - 1
            }
        }
        
        // sort the array by the coil position (innermost-to-outermost)
        self.terminals.sort(by: {$0.coilIndex < $1.coilIndex})
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Min turns
        for i in 0..<8
        {
            if let turns = Double(currentLine[i])
            {
                // the design spreadsheet puts a crazy big number of turns for coils that aren't actually defined
                if turns < 100000
                {
                    self.coils[i].minTurns = turns
                }
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Nom turns
        for i in 0..<8
        {
            if let turns = Double(currentLine[i])
            {
                // the design spreadsheet puts a crazy big number of turns for coils that aren't actually defined
                if turns < 100000
                {
                    self.coils[i].nomTurns = turns
                }
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Max turns
        for i in 0..<8
        {
            if let turns = Double(currentLine[i])
            {
                // the design spreadsheet puts a crazy big number of turns for coils that aren't actually defined
                if turns < 100000
                {
                    self.coils[i].maxTurns = turns
                }
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Electrical Heights
        for i in 0..<8
        {
            if let elHt = Double(currentLine[i])
            {
                self.coils[i].elecHt = elHt * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Spiral Sections?
        for i in 0..<8
        {
            self.coils[i].isHelical = currentLine[i] == "Y"
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Double Stack?
        for i in 0..<8
        {
            self.coils[i].isDoubleStack = currentLine[i] == "Y"
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Multiple Start?
        for i in 0..<8
        {
            self.coils[i].isMultipleStart = currentLine[i] == "Y"
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Axial Sections
        for i in 0..<8
        {
            if self.coils[i].isHelical
            {
                self.coils[i].numAxialSections = self.coils[i].maxTurns
            }
            else if let nAxSect = Double(currentLine[i])
            {
                self.coils[i].numAxialSections = nAxSect
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Gaps (unshrunk)
        for i in 0..<8
        {
            if let axGap = Double(currentLine[i])
            {
                self.coils[i].axialGaps = axGap * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Spacer Width
        for i in 0..<8
        {
            if let spW = Double(currentLine[i])
            {
                self.coils[i].axialSpacerWidth = spW * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Axial Columns
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].numAxialColumns = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Radial Sections
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].numRadialSections = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Interlayer (radial) insulation
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].insulationBetRadialSections = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Radial Ducts
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].numRadialDucts = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Radial duct dimension
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].radialDuctDimn = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Radial Columns
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].numRadialColumns = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Conductor type
        for i in 0..<8
        {
            self.coils[i].condType = currentLine[i]
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Conductors Axial
        for i in 0..<8
        {
            if let nextNum = Int(currentLine[i])
            {
                self.coils[i].numCondAxial = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Num Conductors Radial
        for i in 0..<8
        {
            if let nextNum = Int(currentLine[i])
            {
                self.coils[i].numCondRadial = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Conductor shape
        for i in 0..<8
        {
            self.coils[i].condShape = currentLine[i]
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Total Radial Paper in one turn
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].totalPaperThicknessInOneTurnRadially = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Strand Axial dimension
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].strandA = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Strand Radial Dimension
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].strandR = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Strands per cable (CTC)
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].ctcStrandsPerCable = nextNum
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial center pack
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].axialCenterPack = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Upper Gap
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].axialDVgap1 = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Lower Gap
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].axialDVgap2 = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Bottom edge distance
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].bottomEdgeDistance = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Coil ID
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].coilID = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Overbuild allowance
        if let nextNum = Double(currentLine[0])
        {
            self.overbuildAllowance = nextNum
            
            for i in 0..<8
            {
                self.coils[i].overbuildAllowance = nextNum
            }
        }
        else
        {
            let error = DesignFileError(info: "Bad Overbuild Allowance:" + currentLine[0], type: .InvalidNumber)
            throw error
        }
        
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Max Ground clearance
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].groundClearance = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Short Circuit Factor
        if let nextNum = Double(currentLine[0])
        {
            self.scFactor = nextNum
        }
        else
        {
            let error = DesignFileError(info: "Bad SC Factor:" + currentLine[0], type: .InvalidNumber)
            throw error
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // System GVA
        if let nextNum = Double(currentLine[0])
        {
            self.systemGVA = nextNum
        }
        else
        {
            let error = DesignFileError(info: "Bad System GVA:" + currentLine[0], type: .InvalidNumber)
            throw error
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial distance betweenn CTC cables (if any)
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].axialGapBetweenCables = nextNum * convFactor
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Eddy Loss (file value is in %, we need PU)
        for i in 0..<8
        {
            if let nextNum = Double(currentLine[i])
            {
                self.coils[i].eddyLossAvePU = nextNum / 100.0
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Leg Centers (for version >= 3, this is already im meters)
        if let nextNum = Double(currentLine[0])
        {
            self.legCenters = nextNum
        }
        else
        {
            let error = DesignFileError(info: "Bad Leg Centers:" + currentLine[0], type: .InvalidNumber)
            throw error
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Tank depth
        if let nextNum = Double(currentLine[0])
        {
            self.tankDepth = meters(inches: nextNum)
        }
        else
        {
            let error = DesignFileError(info: "Bad Tank Depth:" + currentLine[0], type: .InvalidNumber)
            throw error
        }

    }
    
}
