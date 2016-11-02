//
//  Phase.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-27.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Foundation

class Phase:NSObject, NSCoding
{
    let core:Core
    var coils:[Coil]
    
    init(core:Core, coils:[Coil])
    {
        self.core = core
        self.coils = coils
    }
    
    convenience required init?(coder aDecoder: NSCoder)
    {
        let core = aDecoder.decodeObject(forKey: "Core") as! Core
        let coils = aDecoder.decodeObject(forKey: "Coils") as! [Coil]
        
        self.init(core:core, coils:coils)
    }
    
    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(self.core, forKey: "Core")
        aCoder.encode(self.coils, forKey: "Coils")
    }
}
