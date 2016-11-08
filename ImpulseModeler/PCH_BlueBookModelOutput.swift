//
//  PCH_BlueBookModelOutput.swift
//  ImpulseModeler
//
//  Created by Peter Huber on 2016-11-06.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

// This class basically exists to simplify saving/opening the file from the internal simulaiton

import Cocoa

class PCH_BlueBookModelOutput: NSObject, NSCoding {

    let timeArray:[Double]
    
    let voltageNodes:[String]
    // The first index is the time index, followed by the node index
    var voltsArray:[[Double]]
    
    let deviceIDs:[String]
    // The first index is the time index, followed by the device index
    var ampsArray:[[Double]]
    
    init(timeArray:[Double], voltageNodes:[String], voltsArray:[[Double]], deviceIDs:[String], ampsArray:[[Double]])
    {
        self.timeArray = timeArray
        self.voltageNodes = voltageNodes
        self.voltsArray = voltsArray
        self.deviceIDs = deviceIDs
        self.ampsArray = ampsArray
    }
    
    convenience init(timeArray:[Double], voltageNodes:[String], voltsMatrix:PCH_Matrix, deviceIDs:[String], ampsMatrix:PCH_Matrix)
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
        
        self.init(timeArray:timeArray, voltageNodes:voltageNodes, voltsArray:voltsArray, deviceIDs:deviceIDs, ampsArray:ampsArray)
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let timeArray = aDecoder.decodeObject(forKey: "Times") as! [Double]
        let voltageNodes = aDecoder.decodeObject(forKey: "VoltageNodes") as! [String]
        let voltsArray = aDecoder.decodeObject(forKey: "Volts") as! [[Double]]
        let deviceIDs = aDecoder.decodeObject(forKey: "DeviceIDs") as! [String]
        let ampsArray = aDecoder.decodeObject(forKey: "Amps") as! [[Double]]
        
        self.init(timeArray:timeArray, voltageNodes:voltageNodes, voltsArray:voltsArray, deviceIDs:deviceIDs, ampsArray:ampsArray)
    }
    
    func encode(with aCoder: NSCoder)
    {
        
        aCoder.encode(self.timeArray, forKey:"Times")
        aCoder.encode(self.voltageNodes, forKey:"VoltageNodes")
        aCoder.encode(self.voltsArray, forKey:"Volts")
        aCoder.encode(self.deviceIDs, forKey:"DeviceIDs")
        aCoder.encode(self.ampsArray, forKey:"Amps")
    }
}
