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
    
    // An array for holding the maximum voltage that appears between nodes. In the interest of keeping the file size down, these values are stored as an "upper triangular" square matrix without the main diagonal (which would be all zeroes). To access the voltage difference between node X (row) and node Y (col) (with Y > X, and both zero-based), the index is X + Y(Y-1)/2. Similarly, the size of the array (for N = numNodes) is N(N-1)/2.
    var maxVoltDiffArray:[Double]
    
    init(timeArray:[Double], sections:[PCH_BB_ModelSection], voltsArray:[[Double]], ampsArray:[[Double]], maxVoltDiffArray:[Double])
    {
        self.timeArray = timeArray
        self.sections = sections
        // self.voltageNodes = voltageNodes
        self.voltsArray = voltsArray
        // self.deviceIDs = deviceIDs
        self.ampsArray = ampsArray
        self.maxVoltDiffArray = maxVoltDiffArray
    }
    
    convenience init(timeArray:[Double], sections:[PCH_BB_ModelSection], voltsMatrix:PCH_Matrix, ampsMatrix:PCH_Matrix, vDiffMatrix:PCH_Matrix)
    {
        // Initialize the voltage array
        var voltsArray = Array(repeatElement(Array(repeatElement(0.0, count: voltsMatrix.numCols)), count: voltsMatrix.numRows))
        
        // Fill the voltage array
        for nextRow in 0..<voltsMatrix.numRows
        {
            for nextCol in 0..<voltsMatrix.numCols
            {
                if fabs(voltsMatrix[nextRow, nextCol]) > 1.0E10
                {
                    DLog("got one")
                }
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
        
        // Initialize the max delta V array. See the definition of maxVoltDiffArray for the way the size is calculated
        let nodeCount = vDiffMatrix.numCols
        var maxVDiffArray = Array(repeatElement(0.0, count: nodeCount * (nodeCount - 1) / 2))
        
        for nextRow in 0..<(vDiffMatrix.numRows - 1)
        {
            for nextCol in (nextRow + 1)..<vDiffMatrix.numCols
            {
                // see the definition of maxVoltDiffArray for the way the index is calculated
                maxVDiffArray[nextRow + nextCol*(nextCol-1)/2] = vDiffMatrix[nextRow, nextCol]
            }
        }
        
        self.init(timeArray:timeArray, sections:sections, voltsArray:voltsArray, ampsArray:ampsArray, maxVoltDiffArray:maxVDiffArray)
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        DLog("Decoding Times...")
        let timeArray = aDecoder.decodeObject(forKey: "Times") as! [Double]
        DLog("Done!\n\nDecoding Sections...")
        let sections = aDecoder.decodeObject(forKey: "Sections") as! [PCH_BB_ModelSection]
        DLog("Done!\n\nDecoding Voltages...")
        // let voltageNodes = aDecoder.decodeObject(forKey: "VoltageNodes") as! [String]
        let voltsArray = aDecoder.decodeObject(forKey: "Volts") as! [[Double]]
        for nextOuter in voltsArray
        {
            for nextInner in nextOuter
            {
                if fabs(nextInner) > 1.0E10
                {
                    DLog("got one!")
                }
            }
        }
        DLog("Done!\n\nDecoding Currents...")
        // let deviceIDs = aDecoder.decodeObject(forKey: "DeviceIDs") as! [String]
        let ampsArray = aDecoder.decodeObject(forKey: "Amps") as! [[Double]]
        DLog("Done!\n\nDecoding Max Voltage Differences...")
        let vDiffArray = aDecoder.decodeObject(forKey: "Diffs") as! [Double]
        DLog("Done!\n\nInitializing local memory...")
        self.init(timeArray:timeArray, sections:sections, voltsArray:voltsArray, ampsArray:ampsArray, maxVoltDiffArray:vDiffArray)
        DLog("Done!")
    }
    
    func encode(with aCoder: NSCoder)
    {
        
        aCoder.encode(self.timeArray, forKey:"Times")
        aCoder.encode(self.sections, forKey:"Sections")
        // aCoder.encode(self.voltageNodes, forKey:"VoltageNodes")
        aCoder.encode(self.voltsArray, forKey:"Volts")
        // aCoder.encode(self.deviceIDs, forKey:"DeviceIDs")
        aCoder.encode(self.ampsArray, forKey:"Amps")
        aCoder.encode(self.maxVoltDiffArray, forKey: "Diffs")
    }
}
