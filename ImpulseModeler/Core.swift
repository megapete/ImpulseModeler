//
//  Core.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Foundation

class Core:NSObject, NSCoding
{
    let diameter:Double
    
    let height:Double
    
    let htFactor:Double
    
    let coilCenterOffset:Double
    
    let legCenters:Double
    
    init(diameter:Double, height:Double, legCenters:Double, htFactor:Double = 3.0, coilCenterOffset:Double = 0.0)
    {
        self.diameter = diameter
        self.height = height
        self.legCenters = legCenters
        self.htFactor = htFactor
        self.coilCenterOffset = coilCenterOffset
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let diameter = aDecoder.decodeDouble(forKey: "Diameter")
        let height = aDecoder.decodeDouble(forKey: "Height")
        let htFactor = aDecoder.decodeDouble(forKey: "HeightFactor")
        let coilCenterOffset = aDecoder.decodeDouble(forKey: "CoilCenterOffset")
        let legCenters = aDecoder.decodeDouble(forKey: "LegCenters")
        
        self.init(diameter:diameter, height:height, legCenters:legCenters, htFactor:htFactor, coilCenterOffset:coilCenterOffset)
    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.diameter, forKey: "Diameter")
        aCoder.encode(self.height, forKey: "Height")
        aCoder.encode(self.htFactor, forKey: "HeightFactor")
        aCoder.encode(self.coilCenterOffset, forKey: "CoilCenterOffset")
        aCoder.encode(self.legCenters, forKey:"LegCenters")
    }
}
