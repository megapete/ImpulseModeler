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
        
        let coil:CoilData
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
    
    enum DesignFileError: Error
    {
        case InvalidDesignFile
        case InvalidNumber(badString:String)
    }
    
    init(withURL:URL)
    {
        var fileString = ""
        
        do
        {
            try fileString = String(contentsOf: designFile)
        }
        catch
        {
            throw error
        }
        
        let fileLines = fileString.components(separatedBy: .newlines)
        var currentIndex = 0
        
        // early checks to see if this is a valid design file
        if fileLines.count < 44 // design file version 2 has 44 lines
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        var currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        if currentLine.count != 8
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        let fileVersion = Int(currentLine[7])
        if fileVersion == nil || fileVersion! != 2
        {
            throw DesignFileError.InvalidDesignFile
        }
        
        // version 2 of the Excel file is all in inches and we want meters, so:
        let convFactor = 25.4 / 1000.0
        
        guard let numPhases = Int(currentLine[0]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Num Phases: " + currentLine[5])
        }
        
        guard var coreDiameter = Double(currentLine[5]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Core Diameter: " + currentLine[5])
        }
        
        coreDiameter *= convFactor
        
        guard var windowHt = Double(currentLine[6]) else
        {
            throw DesignFileError.InvalidNumber(badString: "Bad Core Window height: " + currentLine[6])
        }
        
        windowHt *= convFactor
        
        let core = Core(diameter: coreDiameter, height: windowHt)
        
        // If we got to here, we'll assume that this is a valid Excel design file and stop checking things
        currentIndex += 1
        
        // Coil data
        var coils:[CoilData] = []
        while currentIndex < 9
        {
            currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
            
            coils.append(CoilData(numPhases: numPhases, lineVolts: Double(currentLine[0])!, MVA: Double(currentLine[1])!, Connection: currentLine[2], termNum: Int(currentLine[3])!, currentDir: Int(currentLine[4])!))
            
            currentIndex += 1
        }
        
        // Row
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        var coilIndex = 0
        for nextRow in currentLine
        {
            if let rowNum = Int(nextRow)
            {
                coils[coilIndex].coilPos = rowNum - 1
            }
            
            coilIndex += 1
        }
        
        // we don't care about min turns
        currentIndex += 2
        
        // Nom turns
        currentLine = fileLines[currentIndex].components(separatedBy: .whitespaces)
        
        for var nextCoil in coils
        {
            if nextCoil.coilPos < 0
            {
                continue
            }
            
            nextCoil.nomTurns = Double(currentLine[nextCoil.coilPos])!
        }
    }
    
}
