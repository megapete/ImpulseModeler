//
//  ExcelDesignFile.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2019-10-17.
//  Copyright © 2019 Peter Huber. All rights reserved.
//

// This is intended to be a portable class that can be used by any Swift program to get at the data passed by the Excel desig file to the AndersenFE program. There are also a number of functions to "massage" the raw data. All data is converted from inches to meters before storing.

import Cocoa

class ExcelDesignFile: NSObject
{
    struct CoilData
    {
        var coilPos:Int = -1
        
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
        
        var strandsPerCable:Double = 1.0
        
        var axialCenterPack:Double = 0.0
        var axialDVgap1:Double = 0.0
        var axialDVgap2:Double = 0.0
        
        var bottomEdgeDistance:Double = 0.0
        
        var coilID:Double = 0.0
    }
    
    struct TerminalData
    {
        let lineVolts:Double
        let kVA:Double
        let connection:String
        let termNum:Int
        let currentDirection:Int
        
        var coilIndex:Int = -1
    }
    
    // General Info
    let numPhases:Int
    
    let frequency:Double // Hertz
    
    let tempRise:Double // °C
    
    let onaf1:Double // percent of onan
    let onaf2:Double
    
    let coreDiameter:Double
    let windowHt:Double
    
    let overbuildAllowance:Double
    
    let scFactor:Double
    let systemGVA:Double
    
    var terminals:[TerminalData] = []
    var coils:[CoilData] = Array(repeating: CoilData(), count: 8)
    
    enum DesignFileError: Error
    {
        case InvalidDesignFile
        case InvalidNumber(badString:String)
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
        
        let fileLines = fileString.components(separatedBy: .newlines)
        var currentIndex = 0
        
        // early checks to see if this is a valid design file
        if fileLines.count < 44 // design file version 2 has at least 44 lines
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        var currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        if currentLine.count != 8
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        // for now, we only accept file version 2
        let fileVersion = Int(currentLine[7])
        if fileVersion == nil || fileVersion! != 2
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        // version 2 of the Excel file is all in inches and we want meters, so:
        let convFactor = meterPerInch
        
        guard let nPhases = Int(currentLine[0]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Num Phases: " + currentLine[0])
        }
        
        self.numPhases = nPhases
        
        guard let freq = Double(currentLine[1]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Frequency: " + currentLine[1])
        }
        
        self.frequency = freq
        
        guard let tRise = Double(currentLine[2]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Temp Rise: " + currentLine[2])
        }
        
        self.tempRise = tRise
        
        guard let fans1 = Double(currentLine[3]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad ONAF1: " + currentLine[3])
        }
        
        self.onaf1 = fans1
        
        guard let fans2 = Double(currentLine[4]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad ONAF2: " + currentLine[4])
        }
        
        self.onaf2 = fans2
        
        guard let coreDia = Double(currentLine[5]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Core Diameter: " + currentLine[5])
        }
        
        self.coreDiameter = coreDia * convFactor
        
        guard let windHt = Double(currentLine[6]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Core Window height: " + currentLine[6])
        }
        
        self.windowHt = windHt * convFactor
        
        // If we got to here, we'll assume that this is a valid Excel design file and stop checking things so closely
        currentIndex += 1
        
        // There are 8 rows of terminal data
        for termOffset in 0..<8
        {
            let nextTermLine = fileLines[currentIndex + termOffset].components(separatedBy: .whitespaces)
            
            let nextTerm = TerminalData(lineVolts: Double(nextTermLine[0])!, kVA: Double(nextTermLine[1])!, connection: nextTermLine[2], termNum: Int(nextTermLine[3])!, currentDirection: Int(nextTermLine[4])!)
            
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
                self.coils[i].elecHt = elHt
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
            if let nAxSect = Double(currentLine[i])
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
                self.coils[i].axialGaps = axGap
            }
        }
        
        currentIndex += 1
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        // Axial Spacer Width
        for i in 0..<8
        {
            if let spW = Double(currentLine[i])
            {
                self.coils[i].axialSpacerWidth = spW
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
                self.coils[i].insulationBetRadialSections = nextNum
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
                self.coils[i].radialDuctDimn = nextNum
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
        
    }
    
}
