//
//  ConnectionDlogView.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

struct Node {
    
    let idNum:Int
    var connections:[Int]
    var location:NSPoint
    var currentColor:NSColor
}

class ConnectionDlogView: NSView
{
    let connectorLength = 15.0
    var elementHt:Double? = nil
    var requiredCoilHt:Double? = nil
    let nodeDiameter = 10.0
    let offsetFromBottom = 50.0
    let horizontalOffsetToFirstCoil = 200.0
    let horizontalOffsetBetweenCoils = 100.0
    
    var sections:[PCH_DiskSection]? = nil
    var sectionFields:[NSTextField] = Array()
    var nodes:[Node] = Array()
    
    var nodeRects:[NSRect] = Array()
    var nodeColors:[NSColor] = Array()
    
    // var isFirstTime = true
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        
        // Set the background to white for the view
        NSColor.white.set()
        NSRectFill(self.bounds)
        
        // Draw the "button" around the ground icon
        NSColor.gray.set()
        let groundConnectionRect = NSRect(x: 67.5 - 15.0, y: self.bounds.height - 125.0, width: 30.0, height: 30.0)
        var path = NSBezierPath(roundedRect:groundConnectionRect , xRadius: 5.0, yRadius: 5.0)
        path.stroke()
        
        drawGroundAt(NSPoint(x: 67.5, y: self.bounds.height - 100.0))
        
        // Draw the button around the impulse icon
        NSColor.gray.set()
        let impulseConnectionRect = NSOffsetRect(groundConnectionRect, 0.0, -50.0)
        path = NSBezierPath(roundedRect: impulseConnectionRect, xRadius: 5.0, yRadius: 5.0)
        path.stroke()
        
        drawLightningBoltAt(NSPoint(x:impulseConnectionRect.origin.x + impulseConnectionRect.width / 2.0, y:impulseConnectionRect.origin.y + impulseConnectionRect.height - 0.5))
        
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
        
        // And now the nodes
        for nextNode in self.nodes
        {
            let nodeRect = NSRect(x: nextNode.location.x - CGFloat(self.nodeDiameter / 2.0), y: nextNode.location.y - CGFloat(self.nodeDiameter / 2.0), width: CGFloat(self.nodeDiameter), height: CGFloat(self.nodeDiameter))
            
            let nodePath = NSBezierPath(ovalIn: nodeRect)
            
            nextNode.currentColor.set()
            nodePath.fill()
            
            NSColor.black.set()
            nodePath.stroke()
        }
    }
    
    override var acceptsFirstResponder: Bool
    {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        
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
        let pointInView = self.convert(pointInWindow, to: nil)
        
        for nextNodeRect in nodeRects
        {
            if nextNodeRect.contains(pointInView)
            {
                NSColor.lightGray.set()
            }
            else
            {
                NSColor.white.set()
            }
            
            let nextNode = NSBezierPath(ovalIn: nextNodeRect)
            nextNode.fill()
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
        
        // At this point, the textfields for the disk names have all been set up. Here we will create the nodes and set the rectangles for each text field
        
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
