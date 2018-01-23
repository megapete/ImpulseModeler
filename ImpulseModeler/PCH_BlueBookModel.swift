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
        
        // Each axial section in the model has an "end node" that is not the start node of the next axial section, so we need to make sure we include all those nodes in the matrix.
        var axialSectionCount = 0
        for nextCoil in phase.coils
        {
            axialSectionCount += nextCoil.sections!.count
        }
        let nodeCount = sectionCount + axialSectionCount
        
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
        
        for nextCoil in phase.coils
        {
            for nextAxialSection in nextCoil.sections!
            {
                startNodes.append(nextStart)
                
                nextStart += Int(nextAxialSection.numDisks) + 1
                
                endNodes.append(nextStart - 1)
            }
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
            
            for (sectionID, mutInd) in nextSection.data.mutualInductances
            {
                guard let mutSection = DiskSectionUsingID(sectionID, inModel: theModel)
                else
                {
                    DLog("Bad Section ID!")
                    continue
                }
                
                // only add the mutual inductances once (the matrix is symmetric)
                if (mutSection.data.serialNumber > currentSectionNumber)
                {
                    M[currentSectionNumber, mutSection.data.serialNumber] = mutInd
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
                
                for (sectionID, shuntC) in prevSection!.data.shuntCapacitances
                {
                    guard let shuntCapSection = DiskSectionUsingID(sectionID, inModel: theModel)
                    else
                    {
                        DLog("Bad sectionID!")
                        continue
                    }
                    
                    sumKip += shuntC / 2.0
                    
                    // we don't include ground nodes in this part
                    if (sectionID != "GND")
                    {
                        C[prevSection!.data.nodes.outNode, shuntCapSection.data.nodes.outNode] += -shuntC / 2.0
                    }
                }
                
                C[nextSection.data.nodes.inNode, prevSection!.data.nodes.inNode] = -Cj
                
                A[nextSection.data.nodes.inNode, sectionIndex-1] = 1
            }
            
            let Cj1 = nextSection.data.seriesCapacitance
            
            for (sectionID, shuntC) in nextSection.data.shuntCapacitances
            {
                guard let shuntCapSection = DiskSectionUsingID(sectionID, inModel: theModel)
                    else
                {
                    DLog("Bad sectionID!")
                    continue
                }
                
                sumKip += shuntC / 2.0
                
                if (sectionID != "GND")
                {
                    C[nextSection.data.nodes.inNode, shuntCapSection.data.nodes.inNode] += -shuntC / 2.0
                }
            }
            
            C[nextSection.data.nodes.inNode, nextSection.data.nodes.inNode] = Cj + Cj1 + sumKip
            
            C[nextSection.data.nodes.inNode, nextSection.data.nodes.outNode] = -Cj1
            
            // DLog("Total Kip for this node: \(sumKip)")
            
            // take care of end nodes
            if (endNodes.contains(nextSection.data.nodes.outNode))
            {
                sumKip = 0.0
                
                for (sectionID, shuntC) in nextSection.data.shuntCapacitances
                {
                    guard let shuntCapSection = DiskSectionUsingID(sectionID, inModel: theModel)
                        else
                    {
                        DLog("Bad sectionID!")
                        continue
                    }
                    
                    sumKip += shuntC / 2.0
                    
                    if (sectionID != "GND")
                    {
                        C[nextSection.data.nodes.outNode, shuntCapSection.data.nodes.outNode] += -shuntC / 2.0
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
    
    func SimulateWithConnections(_ connections:[(fromNode:Int, toNodes:[Int])], sourceConnection:(source:PCH_Source, toNode:Int), simTimeStep:Double, saveTimeStep:Double, totalTime:Double) -> (V:PCH_Matrix, I:PCH_Matrix)?
    {
        // Nodes can be connected to ground (they cannot be connected "from" ground), to other nodes, or to the source.
        
        let newC = self.C
        
        var groundedNodes = Set<Int>()
        
        for nextConnection in connections
        {
            if (nextConnection.fromNode == -1)
            {
                ALog("Cannot set the 'from' node as ground!")
                return nil
            }
            
            let fromRow = newC.Submatrix(fromRow: nextConnection.fromNode, toRow: nextConnection.fromNode, fromCol: 0, toCol: newC.numCols - 1)
            var addRow = PCH_Matrix(numRows: 1, numCols: newC.numCols, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
            
            var connectToGround = false
            for toNode in nextConnection.toNodes
            {
                if toNode == -1 || groundedNodes.contains(toNode)
                {
                    connectToGround = true
                    break
                }
                
                // get the equation for toNode and add it to the running sum
                let newRowToAdd = newC.Submatrix(fromRow: toNode, toRow: toNode, fromCol: 0, toCol: newC.numCols - 1)
                addRow += newRowToAdd
                
                // now we change row 's' so that dVs/dt - dVi/dt = 0 (the zero will be handled in the AI calculation below)
                var newSrow = [Double](repeatElement(0.0, count: C.numCols))
                newSrow[toNode] = 1.0
                newSrow[nextConnection.fromNode] = -1.0
                newC.SetRow(toNode, buffer: newSrow)
            }
            
            if connectToGround
            {
                // If any one of the toNodes is ground, them ALL the other toNodes will also go to ground
                // first set the fromNode
                var newRow = [Double](repeatElement(0.0, count: C.numCols))
                newRow[nextConnection.fromNode] = 1.0
                newC.SetRow(nextConnection.fromNode, buffer: newRow)
                groundedNodes.insert(nextConnection.fromNode)
                
                for toNode in nextConnection.toNodes
                {
                    if (toNode != -1)
                    {
                        if !groundedNodes.contains(toNode)
                        {
                            newRow = [Double](repeatElement(0.0, count: C.numCols))
                            newRow[toNode] = 1.0
                            newC.SetRow(toNode, buffer: newRow)
                            groundedNodes.insert(toNode)
                        }
                    }
                }
            }
            else
            {
                newC.SetRow(nextConnection.fromNode, vector: fromRow + addRow)
            }
        }
        
        // Set the row for the node connected to the source
        var newRow = [Double](repeatElement(0.0, count: C.numCols))
        newRow[sourceConnection.toNode] = 1.0
        newC.SetRow(sourceConnection.toNode, buffer: newRow)
        
        let sectionCount = self.A.numCols
        let nodeCount = self.A.numRows
        
        var I = PCH_Matrix(numVectorElements: sectionCount, vectorPrecision: PCH_Matrix.precisions.doublePrecision)
        var V = PCH_Matrix(numVectorElements: nodeCount, vectorPrecision: PCH_Matrix.precisions.doublePrecision)
        
        let numSavedTimeSteps = Int(round(totalTime / saveTimeStep)) + 1
        
        let savedValuesV = PCH_Matrix(numRows: numSavedTimeSteps, numCols: nodeCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
        let savedValuesI = PCH_Matrix(numRows: numSavedTimeSteps, numCols: sectionCount, matrixPrecision: PCH_Matrix.precisions.doublePrecision, matrixType: PCH_Matrix.types.generalMatrix)
        
        var simTime = 0.0
        var timeStepCount = 0
        let saveStepInterval = Int(round(saveTimeStep / simTimeStep))
        
        while simTime <= totalTime
        {
            guard let AI = (A * I)
            else
            {
                ALog("A*I multiply failed")
                return nil
            }
            
            // AI.matrixPrecision = PCH_Matrix.precisions.doublePrecision
            
            for nextGroundedNode in groundedNodes
            {
                AI[nextGroundedNode, 0] = 0.0
            }
            
            // Fix the "connected" nodes
            for nextConnection in connections
            {
                // Grounded nodes were taken care of immediately above
                if (nextConnection.toNodes.contains(-1))
                {
                    continue
                }
                
                var newAI:Double = AI[nextConnection.fromNode, 0]
                for nextToNode in nextConnection.toNodes
                {
                    newAI += AI[nextToNode,0]
                    AI[nextToNode, 0] = 0.0
                }
                
                AI[nextConnection.fromNode, 0] = newAI
            }
            
            // Now the shot, using Runge-Kutta
            AI[sourceConnection.toNode, 0] = sourceConnection.source.dV(simTime)
            let an = newC.SolveWith(AI)!
            
            AI[sourceConnection.toNode, 0] = sourceConnection.source.dV(simTime + simTimeStep / 2.0)
            let bn = newC.SolveWith(AI)!
            let cn = bn
            
            AI[sourceConnection.toNode, 0] = sourceConnection.source.dV(simTime + simTimeStep)
            let dn = newC.SolveWith(AI)!
            
            let newV = V + simTimeStep/6.0 * (an + 2.0 * bn + 2.0 * cn + dn)
            
            guard let BV = (B * newV)
            else
            {
                ALog("B*V multiply failed")
                return nil
            }
            
            guard let RI = (R * I)
            else
            {
                ALog("R*I multiply failed")
                return nil
            }
            
            var rtSide = BV - RI
            
            // The current derivative dI/dt _is_ a function of I, so this is a more "traditional" calculation using Runge-Kutta.
            let aan = M.SolveWith(rtSide)!
            
            var newI = I + (simTimeStep/2.0 * aan)
            rtSide = BV - (R * newI)!
            let bbn = M.SolveWith(rtSide)!
            
            newI = I + (simTimeStep/2.0 * bbn)
            rtSide = BV - (R * newI)!
            let ccn = M.SolveWith(rtSide)!
            
            newI = I + (simTimeStep * ccn)
            rtSide = BV - (R * newI)!
            let ddn = M.SolveWith(rtSide)!
            
            newI = I + simTimeStep/6.0 * (aan + 2.0 * bbn + 2.0 * ccn + ddn)
            
            if (timeStepCount % saveStepInterval == 0)
            {
                DLog("Saving step: \(timeStepCount)")
                savedValuesV.SetRow(timeStepCount / saveStepInterval, vector: newV)
                savedValuesI.SetRow(timeStepCount / saveStepInterval, vector: newI)
            }
            
            V = newV
            I = newI
            
            simTime += simTimeStep
            timeStepCount += 1
        }
        
        return (savedValuesV, savedValuesI)
    
    }
}
