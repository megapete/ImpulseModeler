//
//  PCH_BlueBookModelOutput.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2016-11-06.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

// This class basically exists to simplify saving/opening the file from the internal simulaiton

import Cocoa

// Helper class for encoding the section data we're interested in
class PCH_BB_ModelSection: NSObject, NSCoding
{
    let inNode:Int
    let outNode:Int
    let name:String
    let zDims:(zBottom:Double, zTop:Double)
    
    init(inNode:Int, outNode:Int, name:String, zDims:(Double, Double))
    {
        self.inNode = inNode
        self.outNode = outNode
        self.name = name
        self.zDims = zDims
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let inNode = aDecoder.decodeInteger(forKey: "InNode")
        let outNode = aDecoder.decodeInteger(forKey: "OutNode")
        let name = aDecoder.decodeObject(forKey: "Name") as! String
        let zBottom = aDecoder.decodeDouble(forKey: "Z-Bottom")
        let zTop = aDecoder.decodeDouble(forKey: "Z-Top")
        
        self.init(inNode:inNode, outNode:outNode, name:name, zDims:(zBottom, zTop))
    }
    
    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(self.inNode, forKey: "InNode")
        aCoder.encode(self.outNode, forKey: "OutNode")
        aCoder.encode(self.name, forKey: "Name")
        aCoder.encode(self.zDims.zBottom, forKey:"Z-Bottom")
        aCoder.encode(self.zDims.zTop, forKey:"Z-Top")
    }
}

class PCH_BlueBookModelOutput: NSObject, NSCoding {

    let timeArray:[Double]
    
    let sections:[PCH_BB_ModelSection]
    
    // let voltageNodes:[String]
    // The first index is the time index, followed by the node index
    var voltsArray:[[Double]]
    
    // let deviceIDs:[String]
    // The first index is the time index, followed by the device index
    var ampsArray:[[Double]]
    
    init(timeArray:[Double], sections:[PCH_BB_ModelSection], voltsArray:[[Double]], ampsArray:[[Double]])
    {
        self.timeArray = timeArray
        self.sections = sections
        // self.voltageNodes = voltageNodes
        self.voltsArray = voltsArray
        // self.deviceIDs = deviceIDs
        self.ampsArray = ampsArray
    }
    
    convenience init(timeArray:[Double], sections:[PCH_BB_ModelSection], voltsMatrix:PCH_Matrix, ampsMatrix:PCH_Matrix)
    {
        // Initialize the voltage array
        var voltsArray = Array(repeatElement(Array(repeatElement(0.0, count: voltsMatrix.numCols)), count: voltsMatrix.numRows))
        
        // Fill the voltage array
        for nextRow in 0..<voltsMatrix.numRows
        {
            for nextCol in 0..<voltsMatrix.numCols
            {
                voltsArray[nextRow][nextCol] = voltsMatrix[nextRow,nextCol]
            }
        }
        
        // Initialize the current (amps) array
        var ampsArray = Array(repeatElement(Array(repeatElement(0.0, count: ampsMatrix.numCols)), count: ampsMatrix.numRows))
        
        // Fill the amps array
        for nextRow in 0..<ampsMatrix.numRows
        {
            for nextCol in 0..<ampsMatrix.numCols
            {
                ampsArray[nextRow][nextCol] = ampsMatrix[nextRow,nextCol]
            }
        }
        
        self.init(timeArray:timeArray, sections:sections, voltsArray:voltsArray, ampsArray:ampsArray)
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let timeArray = aDecoder.decodeObject(forKey: "Times") as! [Double]
        let sections = aDecoder.decodeObject(forKey: "Sections") as! [PCH_BB_ModelSection]
        // let voltageNodes = aDecoder.decodeObject(forKey: "VoltageNodes") as! [String]
        let voltsArray = aDecoder.decodeObject(forKey: "Volts") as! [[Double]]
        // let deviceIDs = aDecoder.decodeObject(forKey: "DeviceIDs") as! [String]
        let ampsArray = aDecoder.decodeObject(forKey: "Amps") as! [[Double]]
        
        self.init(timeArray:timeArray, sections:sections, voltsArray:voltsArray, ampsArray:ampsArray)
    }
    
    func encode(with aCoder: NSCoder)
    {
        
        aCoder.encode(self.timeArray, forKey:"Times")
        aCoder.encode(self.sections, forKey:"Sections")
        // aCoder.encode(self.voltageNodes, forKey:"VoltageNodes")
        aCoder.encode(self.voltsArray, forKey:"Volts")
        // aCoder.encode(self.deviceIDs, forKey:"DeviceIDs")
        aCoder.encode(self.ampsArray, forKey:"Amps")
    }
}
