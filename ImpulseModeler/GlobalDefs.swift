//
//  GlobalDefs.swift
//  TransformerModel
//
//  Created by PeterCoolAssHuber on 2015-07-05.
//  Copyright (c) 2015 Peter Huber. All rights reserved.
//

import Foundation

/// Important value #1: π
let π:Double = 3.1415926535897932384626433832795

/// Permeability of vacuum
let µ0:Double = π * 4.0E-7

/// Speed of light
let c:Double = 299792458.0 // m/s

/// Permittivity of free space
let ε0:Double = 1 / (µ0 * c * c) // Farads/m

/// Catalan's constant (used in some inductance calculations)
let G:Double = 0.915965594177219015054603514932384110774

/// Exponential function (this is basically an alias to make it easier to copy formulae)
func e(_ arg:Double) -> Double
{
    return exp(arg)
}

/// Handy constant for 3-phase applications
let SQRT3 = sqrt(3.0)

