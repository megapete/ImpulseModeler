//
//  ConnectionDlogView.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class Node {
    
    let idNum:Int
    var connections:[Int]
    var location:NSPoint
    var currentColor:NSColor
    
    init(idNum:Int, connections:[Int], location:NSPoint, currentColor:NSColor)
    {
        self.idNum = idNum
        self.connections = connections
        self.location = location
        self.currentColor = currentColor
    }
}

class ConnectionDlogView: NSView
{
    let connectorLength = 15.0
    var elementHt:Double? = nil
    var requiredCoilHt:Double? = nil
    let nodeDiameter = 10.0
    let offsetFromBottom = 50.0
    let horizontalOffsetToFirstCoil = 250.0
    let horizontalOffsetBetweenCoils = 150.0
    
    var groundConnectionRect:NSRect?
    var highlightGround = false
    
    var impulseConnectionRect:NSRect?
    
    var sections:[PCH_DiskSection]? = nil
    var sectionFields:[NSTextField] = Array()
    var nodes:[Node] = Array()
    
    var startNode:Node? = nil
    var finishPoint:NSPoint? = nil
    
    let connectorBlue = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.75)
    let connectingBlue = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.5)
    
    var connections:[(fromNode:Node, toNode:Node)] = Array()
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        
        // Set the background to white for the view
        NSColor.white.set()
        NSRectFill(self.bounds)
        
        // Draw the "button" around the ground icon
        
        if let grdConnRect = self.groundConnectionRect
        {
            NSColor.gray.set()
            let path = NSBezierPath(roundedRect:grdConnRect , xRadius: 5.0, yRadius: 5.0)
            path.stroke()
            
            self.nodes[0].currentColor.set()
            path.fill()
            
            drawGroundAt(NSPoint(x: grdConnRect.origin.x + 15.0, y: grdConnRect.origin.y + grdConnRect.height - 5.0))
        }
        
        // Draw the button around the impulse icon
        if let impConnRect = self.impulseConnectionRect
        {
            NSColor.gray.set()
            let path = NSBezierPath(roundedRect: impConnRect, xRadius: 5.0, yRadius: 5.0)
            path.stroke()
            
            self.nodes[1].currentColor.set()
            path.fill()
            
            drawLightningBoltAt(NSPoint(x:impConnRect.origin.x + impConnRect.width / 2.0, y:impConnRect.origin.y + impConnRect.height - 0.5))
        }
        
        // Start by showing the disks and connectors
        for nextField in self.sectionFields
        {
            NSColor.black.set()
            
            // Show the border around the disk name (using isBordered is UGLY)
            let borderRect = NSRect(x: nextField.frame.origin.x - 2.0, y: nextField.frame.origin.y - 4.0, width: nextField.frame.width + 7.0, height: nextField.frame.height + 7.0)
            let borderPath = NSBezierPath(rect: borderRect)
            borderPath.stroke()
            
            let connectorPath = NSBezierPath()
            let connectorX = borderRect.origin.x + borderRect.width / 2.0
            
            // Draw the connector coming out the bottom of the disk
            connectorPath.move(to: NSPoint(x: connectorX, y: borderRect.origin.y))
            connectorPath.relativeLine(to: NSPoint(x: 0.0, y: CGFloat(-connectorLength)))
            connectorPath.stroke()
            
            // Draw the connector coming out the top of the disk
            connectorPath.move(to: NSPoint(x: connectorX, y: borderRect.origin.y + borderRect.height))
            connectorPath.relativeLine(to: NSPoint(x: 0.0, y: CGFloat(connectorLength)))
            connectorPath.stroke()
        }
        
        // Show any connectors that we may have made
        for nextConnection in self.connections
        {
            let thePath = NSBezierPath()
            thePath.move(to: nextConnection.fromNode.location)
            thePath.lineWidth = 1.5
            
            if nextConnection.toNode.idNum == -1
            {
                // handle ground
                thePath.relativeLine(to: NSPoint(x: -50.0, y: -15.0))
                NSColor.green.set()
                thePath.stroke()
                self.drawGroundAt(thePath.currentPoint)
            }
            else if (nextConnection.toNode.idNum == -2)
            {
                // handle impulse generator
                thePath.relativeLine(to: NSPoint(x: 50.0, y: 15.0))
                NSColor.red.set()
                thePath.stroke()
                
                // x+3.0, y+24.0
                let startPt = NSPoint(x: thePath.currentPoint.x + 3.0, y: thePath.currentPoint.y + 24.0)
                self.drawLightningBoltAt(startPt)
            }
            else
            {
                thePath.line(to: nextConnection.toNode.location)
                self.connectorBlue.set()
                thePath.stroke()
            }
        }
        
        // And now the nodes
        for nextNode in self.nodes
        {
            if nextNode.idNum < 0
            {
                // the node is either ground or the impulse generator, so ignore it
                continue
            }
            
            let nodeRect = NSRect(x: nextNode.location.x - CGFloat(self.nodeDiameter / 2.0), y: nextNode.location.y - CGFloat(self.nodeDiameter / 2.0), width: CGFloat(self.nodeDiameter), height: CGFloat(self.nodeDiameter))
            
            let nodePath = NSBezierPath(ovalIn: nodeRect)
            
            nextNode.currentColor.set()
            nodePath.fill()
            
            NSColor.black.set()
            nodePath.stroke()
        }
        
        if let stNode = self.startNode
        {
            let connectionPath = NSBezierPath()
            connectionPath.move(to: stNode.location)
            connectionPath.line(to: self.finishPoint!)
            connectionPath.lineWidth = 3.0
            self.connectingBlue.set()
            connectionPath.stroke()
        }
    }
    
    override var acceptsFirstResponder: Bool
    {
        return true
    }
    
    override func mouseUp(with event: NSEvent)
    {
        if let fromNode = self.startNode
        {
            let pointInWindow = event.locationInWindow
            self.finishPoint = self.convert(pointInWindow, from: nil)

            if self.groundConnectionRect!.contains(self.finishPoint!)
            {
                // only create the connection if it is not to and from the same node
                if fromNode !== self.nodes[0]
                {
                    self.connections.append((fromNode:fromNode, toNode:self.nodes[0]))
                    fromNode.connections.append(-1)
                    
                    self.nodes[0].currentColor = NSColor.white
                }
                
                
            }
            else if self.impulseConnectionRect!.contains(self.finishPoint!)
            {
                if fromNode !== self.nodes[1]
                {
                    self.connections.append((fromNode:fromNode, toNode:self.nodes[1]))
                    fromNode.connections.append(-2)
                    
                    self.nodes[1].currentColor = NSColor.white
                }
            }
            else
            {
                for nextNode in self.nodes
                {
                    if (nextNode.idNum < 0)
                    {
                        continue
                    }
                    
                    let nodeRadius = CGFloat(self.nodeDiameter / 2.0)
                    let checkRect = NSRect(x: nextNode.location.x - nodeRadius, y: nextNode.location.y - nodeRadius, width: nodeRadius * 2.0, height: nodeRadius * 2.0)
                    
                    if checkRect.contains(self.finishPoint!)
                    {
                        if fromNode.idNum < 0
                        {
                            nextNode.connections.append(fromNode.idNum)
                        }
                        else
                        {
                            fromNode.connections.append(nextNode.idNum)
                        }
                        
                        self.connections.append((fromNode:nextNode, toNode:fromNode))
                        
                        nextNode.currentColor = NSColor.white
                    }
                    
                }
            }
            
            fromNode.currentColor = NSColor.white
            
            self.startNode = nil
            self.needsDisplay = true
        }
        else
        {
            super.mouseUp(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent)
    {
        guard let window = event.window
            else
        {
            super.mouseDragged(with: event)
            return
        }
        
        guard let viewsWindow = self.window
            else
        {
            super.mouseDragged(with: event)
            return
        }
        
        if (viewsWindow != window)
        {
            super.mouseDragged(with: event)
            return
        }
        
        if self.startNode != nil
        {
            let pointInWindow = event.locationInWindow
            self.finishPoint = self.convert(pointInWindow, from: nil)
            
            if self.groundConnectionRect!.contains(self.finishPoint!)
            {
                self.nodes[0].currentColor = self.connectingBlue
            }
            else if self.startNode !== self.nodes[0]
            {
                self.nodes[0].currentColor = NSColor.white
            }
                
            if self.impulseConnectionRect!.contains(self.finishPoint!)
            {
                self.nodes[1].currentColor = self.connectingBlue
            }
            else if self.startNode !== self.nodes[1]
            {
                self.nodes[1].currentColor = NSColor.white
            }
            
            for nextNode in self.nodes
            {
                if nextNode.idNum < 0
                {
                    // we took care of ground and impulse generator above
                    continue
                }
                
                let nodeRadius = CGFloat(self.nodeDiameter / 2.0)
                let checkRect = NSRect(x: nextNode.location.x - nodeRadius, y: nextNode.location.y - nodeRadius, width: nodeRadius * 2.0, height: nodeRadius * 2.0)
                
                if checkRect.contains(self.finishPoint!)
                {
                    nextNode.currentColor = self.connectingBlue
                }
                else if self.startNode !== nextNode
                {
                    nextNode.currentColor = NSColor.white
                }
            }
            
            self.needsDisplay = true
        }
        
        self.autoscroll(with: event)
    }
    
    override func mouseDown(with event: NSEvent)
    {
        
        guard let window = event.window
        else
        {
            super.mouseDown(with: event)
            return
        }
        
        guard let viewsWindow = self.window
        else
        {
            super.mouseDown(with: event)
            return
        }
        
        if (viewsWindow != window)
        {
            super.mouseDown(with: event)
            return
        }
        
        let pointInWindow = event.locationInWindow
        let pointInView = self.convert(pointInWindow, from: nil)
        
        if self.groundConnectionRect!.contains(pointInView)
        {
            DLog("Got ground click")
            self.nodes[0].currentColor = self.connectingBlue
            self.startNode = self.nodes[0]
            self.finishPoint = self.startNode!.location
            self.needsDisplay = true
            return
        }
        
        if self.impulseConnectionRect!.contains(pointInView)
        {
            self.nodes[1].currentColor = self.connectingBlue
            self.startNode = self.nodes[1]
            self.finishPoint = self.startNode!.location
            self.needsDisplay = true
            return
        }
        
        for nextNode in self.nodes
        {
            if nextNode.idNum < 0
            {
                // we took care of ground and impulse generator above
                continue
            }
            
            let nodeRadius = CGFloat(self.nodeDiameter / 2.0)
            let checkRect = NSRect(x: nextNode.location.x - nodeRadius, y: nextNode.location.y - nodeRadius, width: nodeRadius * 2.0, height: nodeRadius * 2.0)
            
            if checkRect.contains(pointInView)
            {
                nextNode.currentColor = self.connectingBlue
                self.startNode = nextNode
                self.finishPoint = self.startNode!.location
                self.needsDisplay = true
                return
            }
        }
    }
    
    func setUpView()
    {
        guard let theSections = self.sections
        else
        {
            ALog("No sections defined")
            return
        }
        
        self.fixFrameRect()
        
        // At this point, the textfields for the disk names have all been set up. Here we will create the nodes and set the rectangles for each text field.
        
        // First we'll set the special nodes for ground (index 0) and the impulse generator (index 1). Start with the rectangles for their "nodes".
        self.groundConnectionRect = NSRect(x: 67.5 - 15.0, y: self.bounds.height - 125.0, width: 30.0, height: 30.0)
        self.impulseConnectionRect = NSOffsetRect(self.groundConnectionRect!, 0.0, -50.0)
        
        let gndNode = Node(idNum: -1, connections: Array(), location: NSPoint(x:self.groundConnectionRect!.origin.x + self.groundConnectionRect!.width / 2.0, y:self.groundConnectionRect!.origin.y + self.groundConnectionRect!.height / 2.0), currentColor: NSColor.white)
        self.nodes.append(gndNode)
        
        let impgenNode = Node(idNum: -2, connections: Array(), location: NSPoint(x:self.impulseConnectionRect!.origin.x + self.impulseConnectionRect!.width / 2.0, y:self.impulseConnectionRect!.origin.y + self.impulseConnectionRect!.height / 2.0), currentColor: NSColor.white)
        self.nodes.append(impgenNode)
        
        var previousSection:PCH_DiskSection? = nil
        var currentInNodeCenter = NSPoint(x: self.horizontalOffsetToFirstCoil, y: self.offsetFromBottom)

        for i in 0..<theSections.count
        {
            let currSection = theSections[i]
            
            if let prevSection = previousSection
            {
                let prevSectionCoilName = PCH_StrLeft(prevSection.data.sectionID, length: 2)
                let currSectionCoilName = PCH_StrLeft(currSection.data.sectionID, length: 2)
                
                if (prevSectionCoilName == currSectionCoilName)
                {
                    if prevSection.data.nodes.outNode != currSection.data.nodes.inNode
                    {
                        // there's a break in the coil, save the outNode of the previous section
                        let outNode = Node(idNum: prevSection.data.nodes.outNode, connections: Array(), location: currentInNodeCenter, currentColor: NSColor.white)
                        
                        self.nodes.append(outNode)
                        
                        currentInNodeCenter.y += CGFloat(self.connectorLength)
                    }
                }
                else
                {
                    // we've started a new coil, show the final outNode of the previous coil, then start the new one
                    
                    let outNode = Node(idNum: prevSection.data.nodes.outNode, connections: Array(), location: currentInNodeCenter, currentColor: NSColor.white)
                    
                    self.nodes.append(outNode)
                    
                    currentInNodeCenter.x += CGFloat(self.horizontalOffsetBetweenCoils)
                    currentInNodeCenter.y = CGFloat(self.offsetFromBottom)
                }
            }
            
            let inNode = Node(idNum: currSection.data.nodes.inNode, connections: Array(), location: currentInNodeCenter, currentColor: NSColor.white)
            
            self.nodes.append(inNode)
            
            // Set the rectangle of the textfield with the disk name
            let oldFrame = self.sectionFields[i].frame
            let newFrame = NSRect(x: currentInNodeCenter.x - (oldFrame.width + 7.0) / 2.0 + 2.0, y: currentInNodeCenter.y + CGFloat(self.connectorLength) + 4.0, width: oldFrame.width, height: oldFrame.height)
            
            self.sectionFields[i].frame = newFrame
            
            currentInNodeCenter.y += CGFloat(self.elementHt!)
            
            // check if this is the last section in the array and if so, set it's outNode
            if i == theSections.count - 1
            {
                let outNode = Node(idNum: currSection.data.nodes.outNode, connections: Array(), location: currentInNodeCenter, currentColor: NSColor.white)
                
                self.nodes.append(outNode)
            }
            
            previousSection = currSection
        }
        
        
    }
    
    func fixFrameRect()
    {
        let requiredHeight = self.calculateCoilHeight() + 2.0 * self.offsetFromBottom
        
        let scrollView = self.superview!
        
        if (scrollView.frame.height < CGFloat(requiredHeight))
        {
            let yOffset = CGFloat(requiredHeight) - scrollView.frame.height
            
            let newFrame = NSRect(x: scrollView.frame.origin.x, y: scrollView.frame.origin.y - yOffset, width: scrollView.frame.width, height: CGFloat(requiredHeight))
            
            self.frame = newFrame
        }
    }
    
    func calculateCoilHeight() -> Double
    {
        if let requiredHt = self.requiredCoilHt
        {
            // we've already calculated this, just return the value
            return requiredHt
        }
        
        var result = 0.0
        
        let sectArray = self.sections!
        
        if (self.elementHt == nil)
        {
            self.createFieldsForSections()
        }
        
        var lastSection:PCH_DiskSection? = nil
        
        var currentCoilHt = 0.0
        
        for nextSection in sectArray
        {
            if lastSection != nil
            {
                let lastSectionCoil = PCH_StrLeft(lastSection!.data.sectionID, length: 2)
                let nextSectionCoil = PCH_StrLeft(nextSection.data.sectionID, length: 2)
                
                if (lastSectionCoil == nextSectionCoil)
                {
                    if lastSection!.data.nodes.outNode != nextSection.data.nodes.inNode
                    {
                        // There's a break in the coil, add space for a connector in case that's what the user wants
                        currentCoilHt += connectorLength
                    }
                }
                else
                {
                    // we've finished with the previous coil, save it's length if it's longer than whatever is currently in there
                    if currentCoilHt > result
                    {
                        result = currentCoilHt
                    }
                    
                    currentCoilHt = 0.0
                }
            }
            
            currentCoilHt += elementHt!
            
            lastSection = nextSection
        }
        
        self.requiredCoilHt = result
        
        return result
    }
    
    func createFieldsForSections()
    {
        guard let sectArray = sections
        else
        {
            DLog("No sections defined!")
            return
        }
        
        for nextSection in sectArray
        {
            let nextField = NSTextField(labelWithString: nextSection.data.sectionID)
            
            if (elementHt == nil)
            {
                elementHt = Double(nextField.frame.height) + 7.0 + 2.0 * self.connectorLength
            }
            
            nextField.isBordered = false
            nextField.isHidden = false
            nextField.alignment = NSTextAlignment.center
            
            self.sectionFields.append(nextField)
            self.addSubview(nextField)
        }
    }
    
    func drawLightningBoltAt(_ point:NSPoint)
    {
        let path = NSBezierPath()
        
        var nextLocation = point
        nextLocation.x += 6.0
        nextLocation.y -= 5.0
        
        path.move(to: nextLocation)
        nextLocation.x -= 4.0
        path.line(to: nextLocation)
        nextLocation.x -= 6.0
        nextLocation.y -= 12.0
        path.line(to: nextLocation)
        nextLocation.x += 4.0
        path.line(to: nextLocation)
        nextLocation.x -= 3.0
        nextLocation.y -= 7.0
        path.line(to: nextLocation)
        nextLocation.x += 8.0
        nextLocation.y += 10.0
        path.line(to: nextLocation)
        nextLocation.x -= 3.0
        path.line(to: nextLocation)
        nextLocation.x += 4.0
        nextLocation.y += 9.0
        path.line(to: nextLocation)
        
        NSColor.red.set()
        path.fill()
        NSColor.lightGray.set()
        path.stroke()
        
    }
    
    func drawGroundAt(_ point:NSPoint)
    {
        let tailLength:CGFloat = 10.0
        let widestWidth:CGFloat = 17.0
        let widthDiff:CGFloat = 4.0
        let htBetweenLines:CGFloat = 2.5
        let numLines = 5
        
        let path = NSBezierPath()
        
        var nextLocation = point
        path.move(to: nextLocation)
        nextLocation.y -= tailLength
        path.line(to: nextLocation)
        
        var currentWidth = widestWidth
        for _ in 0..<numLines
        {
            nextLocation.x = point.x - currentWidth / 2.0
            path.move(to: nextLocation)
            nextLocation.x += currentWidth
            path.line(to: nextLocation)
            
            nextLocation.y -= htBetweenLines
            currentWidth -= widthDiff
        }
        
        NSColor.green.set()
        path.lineWidth = 1.0
        path.stroke()
        
    }
    
}
