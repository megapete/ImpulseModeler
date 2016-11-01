//
//  PCH_BlueBookModel.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-01.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class PCH_BlueBookModel: NSObject {

    // The inductance matrix
    let M:PCH_Matrix
    
    // The resistance Matrix
    let R:PCH_Matrix
    
    // The capacitance matrix (without connections)
    let C:PCH_Matrix
    
    // The "multiplier" matrices
    let A:PCH_Matrix
    let B:PCH_Matrix
    
    init(theModel:[PCH_DiskSection], phase:Phase)
    {
        let sectionCount = theModel.count
        let coilCount = phase.coils.count
        let nodeCount = sectionCount + coilCount
        
        self.M = PCH_Matrix(numRows: sectionCount, numCols: sectionCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.positiveDefinite)
        
        self.R = PCH_Matrix(numRows: sectionCount, numCols: sectionCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.diagonalMatrix)
        
        // B could be defined as a banded matrix, but at the time of this writing, multiplication has not yet been implemented for banded matrices in PCH_Matrix.
        self.B = PCH_Matrix(numRows: sectionCount, numCols: nodeCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
        
        // A could also be defined as banded, see the comment above for matrix B
        self.A = PCH_Matrix(numRows: nodeCount, numCols: sectionCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
        
        self.C = PCH_Matrix(numRows: nodeCount, numCols: nodeCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
        
        var startNodes = [Int]()
        var endNodes = [Int]()
        var nextStart = 0
        
        for i in 0..<coilCount
        {
            startNodes.append(nextStart)
            
            nextStart += Int(phase.coils[i].numDisks) + 1
            
            endNodes.append(nextStart - 1)
        }
        
        // we need to keep track of the previous section for the capacitance matrix
        var prevSection:PCH_DiskSection? = nil
        
        for sectionIndex in 0..<sectionCount
        {
            let nextSection = theModel[sectionIndex]
            
            if (startNodes.contains(nextSection.data.nodes.inNode))
            {
                prevSection = nil
            }
            
            let currentSectionNumber = nextSection.data.serialNumber
            
            // start with the inductance matrix
            M[currentSectionNumber, currentSectionNumber] = nextSection.data.selfInductance
            
            for (section, mutInd) in nextSection.data.mutInd
            {
                // only add the mutual inductances once (the matrix is symmetric)
                if (section.data.serialNumber > currentSectionNumber)
                {
                    M[currentSectionNumber, section.data.serialNumber] = mutInd
                    // M[section.data.serialNumber, currentSectionNumber] = mutInd
                }
            }
            
            // Now we do the resistance matrix
            R[currentSectionNumber, currentSectionNumber] = nextSection.data.resistance
            
            // And the B matrix
            B[currentSectionNumber, nextSection.data.nodes.inNode] = 1.0
            B[currentSectionNumber, nextSection.data.nodes.outNode] = -1.0
            
            // We will adopt the ATP style of dividing the shunt capacitances in two for each section and applying it out of each node (and thus to each node) of the connected section.
            
            // We need to take care of the bottommost and topmost nodes of each coil
            var Cj = 0.0
            var sumKip = 0.0
            if (prevSection != nil)
            {
                Cj = prevSection!.data.seriesCapacitance
                
                for (section, shuntC) in prevSection!.data.shuntCaps
                {
                    sumKip += shuntC / 2.0
                    
                    // we don't include ground nodes in this part
                    if (section.data.sectionID != "GND")
                    {
                        C[prevSection!.data.nodes.outNode, section.data.nodes.outNode] = -shuntC / 2.0
                    }
                }
                
                C[nextSection.data.nodes.inNode, prevSection!.data.nodes.inNode] = -Cj
                
                A[nextSection.data.nodes.inNode, sectionIndex-1] = 1
            }
            
            let Cj1 = nextSection.data.seriesCapacitance
            
            for (section, shuntC) in nextSection.data.shuntCaps
            {
                sumKip += shuntC / 2.0
                
                if (section.data.sectionID != "GND")
                {
                    C[nextSection.data.nodes.inNode, section.data.nodes.inNode] += -shuntC / 2.0
                }
            }
            
            C[nextSection.data.nodes.inNode, nextSection.data.nodes.inNode] = Cj + Cj1 + sumKip
            
            /* taken care of above
             if (prevSection != nil)
             {
             Cbase[nextSection.data.nodes.inNode, prevSection!.data.nodes.inNode] = -Cj
             }
             */
            
            C[nextSection.data.nodes.inNode, nextSection.data.nodes.outNode] = -Cj1
            
            /* taken care of above
             if (prevSection != nil)
             {
             A[nextSection.data.nodes.inNode, sectionIndex-1] = 1
             }
             */
            
            // DLog("Total Kip for this node: \(sumKip)")
            
            // take care of the final node
            if (endNodes.contains(nextSection.data.nodes.outNode))
            {
                sumKip = 0.0
                for (section, shuntC) in nextSection.data.shuntCaps
                {
                    sumKip += shuntC / 2.0
                    
                    if (section.data.sectionID != "GND")
                    {
                        // Cbase[nextSection.data.nodes.outNode, section.data.nodes.inNode] += -shuntC / 2.0
                        C[nextSection.data.nodes.outNode, section.data.nodes.outNode] += -shuntC / 2.0
                    }
                }
                
                Cj = Cj1
                
                C[nextSection.data.nodes.outNode, nextSection.data.nodes.outNode] = Cj + sumKip
                
                C[nextSection.data.nodes.outNode, nextSection.data.nodes.inNode] = -Cj
                
                A[nextSection.data.nodes.outNode, sectionIndex] = 1
            }
            
            A[nextSection.data.nodes.inNode, sectionIndex] = -1
            
            prevSection = nextSection
        }

    }
}
