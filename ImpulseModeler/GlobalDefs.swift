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

/// Relative dielectric constants for certain materials
let εPaper = 3.5 // oil-soaked
let εOil = 2.2
let εBoard = 4.5 // oil-soaked


/// Function for converting an array of type [Data] (saved in C or Objective-C to an array of type "C-struct". This is handy for when an array of structs is saved in Objective-C using a call like this: [someDataArray addObject:[NSData dataWithBytes:&cStructInstance length:sizeof(struct cStruct)]]
func ConvertDataArray<T>(dataArray:[Data]) -> [T]?
{
    var result:[T] = []
    // we need to use stride because that is the memory "distance" between instances in an array (which is what we have in this case). The actual size of the struct is MemoryLayout<T>.size
    let dataStride = MemoryLayout<T>.stride
    
    for nextData in dataArray
    {
        let tPtr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        let tBuffer = UnsafeMutableBufferPointer(start: tPtr, count: 1)
        let numBytes = nextData.copyBytes(to: tBuffer)
        
        if numBytes != dataStride
        {
            DLog("Stride: \(dataStride); Bytes Transferred: \(numBytes)")
            return nil
        }
        
        result.append(tBuffer[0])
        
        // since we allocated the memory for the pointer, we are responsible for deallocating it as well
        tPtr.deallocate()
    }
    
    return result
}


/// My own complex-number struct
struct Complex:CustomStringConvertible, Hashable
{
    var real:Double
    var imag:Double
    
    /*
    var hashValue: Int
    {
        return self.real.hashValue ^ self.imag.hashValue &* 16777619
    }
    */
    
    static func == (lhs:Complex, rhs:Complex) -> Bool
    {
        return lhs.real == rhs.real && lhs.imag == rhs.imag
    }
    
    static func + (left:Complex, right:Complex) -> Complex
    {
        return Complex(real: left.real + right.real, imag: left.imag + right.imag)
    }
    
    static func += (left:inout Complex, right:Complex)
    {
        left = left + right
    }
    
    static func - (left:Complex, right:Complex) -> Complex
    {
        return Complex(real: left.real - right.real, imag: left.imag - right.imag)
    }
    
    static func -= (left:inout Complex, right:Complex)
    {
        left = left - right
    }
    
    
    /// Operator '*' for Complex * Double
    static func *(left:Complex, right:Double) -> Complex
    {
        let newRight = Complex(real: right)
        
        return left * newRight
    }
    
    /// Operator '*' (multiplication) for the Complex struct
    static func * (left:Complex, right:Complex) -> Complex
    {
        // Note: This method comes from https://en.wikipedia.org/wiki/Complex_number#Elementary_operations
        
        let a = left.real
        let b = left.imag
        
        let c = right.real
        let d = right.imag
        
        return Complex(real: a*c - b*d, imag: b*c + a*d)
    }
    
    static prefix func -(num:Complex) -> Complex
    {
        return Complex(real: -num.real, imag: -num.imag)
    }
    
    static func *= (left:inout Complex, right:Complex)
    {
        left = left * right
    }
    
    /// Operator '/' (division) for the Complex struct
    static func / (left:Complex, right:Complex) -> Complex
    {
        // Note: This method comes from https://en.wikipedia.org/wiki/Complex_number#Elementary_operations
        
        let a = left.real
        let b = left.imag
        
        let c = right.real
        let d = right.imag
        
        if c == 0.0 && d == 0.0
        {
            DLog("Cannot divide by zero!")
            return ComplexNan
        }
        
        let denominator = c*c + d*d
        
        return Complex(real: (a*c + b*d) / denominator, imag: (b*c - a*d) / denominator)
    }
    
    static func /= (left:inout Complex, right:Complex)
    {
        left = left / right
    }
    
    static let ComplexNan:Complex = Complex(real: Double.greatestFiniteMagnitude, imag: Double.greatestFiniteMagnitude)
    static let ComplexZero:Complex = Complex(real: 0.0, imag: 0.0)
    
    init(real:Double, imag:Double = 0)
    {
        self.real = real
        self.imag = imag
    }
    
    init(real:CGFloat)
    {
        self.real = Double(real)
        self.imag = 0.0
    }
    
    /// Absolute value
    var cabs:Double
    {
        return sqrt(self.real * self.real + self.imag * self.imag)
    }
    
    /// Argument (angle) in radians
    var carg:Double
    {
        let x = self.real
        let y = self.imag
        
        if x == 0 && y == 0
        {
            DLog("Cannot compute angle of 0-length vector!")
            return -Double.greatestFiniteMagnitude
        }
        
        if (x > 0.0)
        {
            return atan(y / x)
        }
        else if (x < 0.0 && y >= 0.0)
        {
            return atan(y / x) + π
        }
        else if (x < 0.0 && y < 0.0)
        {
            return atan(y / x) - π
        }
        else if (x == 0.0 && y > 0.0)
        {
            return π / 2.0
        }
        else
        {
            return -π / 2.0
        }
    }
    
    /// Simple conjugate function
    var conjugate:Complex
    {
        return Complex(real: self.real, imag: -self.imag)
    }
    
    // This is what shows up in 'print' statements
    var description:String
    {
        if self == Complex.ComplexNan
        {
            return "ComplexNAN"
        }
        
        var result = ""
        
        if (self.real == 0.0 && self.imag == 0.0)
        {
            result = "0.0"
        }
        
        if (self.real != 0.0)
        {
            result += "\(self.real)"
        }
        
        if (self.imag != 0.0)
        {
            if (self.real != 0.0)
            {
                result += " "
                
                if (self.imag < 0)
                {
                    result += "- "
                }
                else
                {
                    result += "+ "
                }
                
                result += "\(abs(self.imag))i"
            }
            else
            {
                result = "\(self.imag)i"
            }
        }
        
        return result
    }
} // END Complex class definition


// A helper function to convert the 4 control points of a cubic Bezier curve (this is what NSBezierPath uses) and a 't' value (see https://en.wikipedia.org/wiki/Bézier_curve for definitions) into an actual point on the curve. The 't' value is between 0 and 1, with B(t) equal to the point that is 't' along the curve (t=0 is the start point, t=1 is the end point)
func PointOnCurve(points:[NSPoint], t:CGFloat) -> NSPoint
{
    let oneMinusT = 1.0 - t
    
    let x:[CGFloat] = [points[0].x, points[1].x, points[2].x, points[3].x]
    let y:[CGFloat] = [points[0].y, points[1].y, points[2].y, points[3].y]
    
    let BtX = oneMinusT * oneMinusT * oneMinusT * x[0] + 3.0 * oneMinusT * oneMinusT * t * x[1] + 3.0 * oneMinusT * t * t * x[2] + t * t * t * x[3]
    
    let BtY = oneMinusT * oneMinusT * oneMinusT * y[0] + 3.0 * oneMinusT * oneMinusT * t * y[1] + 3.0 * oneMinusT * t * t * y[2] + t * t * t * y[3]
    
    return NSPoint(x: BtX, y: BtY)
}


/// Useful conversion factors
let psiPerNmm2 = 145.038
let nmm2PerPsi = 1.0 / psiPerNmm2
let lbsPerKg = 2.20462
let kgPerlb = 1.0 / lbsPerKg
let farenheitPerKelvin = 9.0 / 5.0
let kelvinPerFarenheit = 5.0 / 9.0
let farenheitPerCelsius = 9.0 / 5.0
let celsiusPerFarenheit = 5.0 / 9.0
let mmPerInch = 25.4
let inchPerMm = 1.0 / 25.4
let meterPerInch = mmPerInch / 1000.0
let inchPerMeter = 1.0 / meterPerInch
let meterPerFoot = meterPerInch * 12.0
let footPerMeter = 1.0 / meterPerFoot

/// Useful conversion functions
func kilos(pounds:Double) -> Double
{
    return pounds * kgPerlb
}

func Nmm2(psi:Double) -> Double
{
    return psi * nmm2PerPsi
}

func meters(feet:Double) -> Double
{
    return feet * meterPerFoot
}

func meters(inches:Double) -> Double
{
    return inches * meterPerInch
}


