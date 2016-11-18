//
//  ConnectionDlogView.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-11-15.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

class ConnectionDlogView: NSView
{
    // let textFieldHt = 17.0
    let connectorLength = 15.0
    var elementHt:Double? = nil
    let nodeDiameter = 10.0
    
    var sections:[PCH_DiskSection]? = nil
    var sectionFields:[NSTextField] = Array()
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        
        // Set the background to white for the view
        NSColor.white.set()
        NSRectFill(self.bounds)

        // Drawing code here.
        
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
        
        // Show the disks and nodes
        var lastCoilName = ""
        var horizontalOffset = CGFloat(100.0)
        var verticalOffset = CGFloat(50.0)
        
        NSColor.black.set()
        
        var lastTopCircleCenter = NSPoint(x: 0.0, y: 0.0)
        
        for nextField in sectionFields
        {
            let nextCoilName = PCH_StrLeft(nextField.stringValue, length: 2)
            
            if nextCoilName != lastCoilName
            {
                if lastCoilName != ""
                {
                    // Show the final top node over the previous coil
                    let nodeCircleRect = NSRect(x: lastTopCircleCenter.x - CGFloat(nodeDiameter) / 2.0, y: lastTopCircleCenter.y - CGFloat(nodeDiameter) / 2.0, width: CGFloat(nodeDiameter), height: CGFloat(nodeDiameter))
                    let nodeCirclePath = NSBezierPath(ovalIn: nodeCircleRect)
                    
                    NSColor.white.set()
                    nodeCirclePath.fill()
                    
                    NSColor.black.set()
                    nodeCirclePath.stroke()
                }
                
                // change the offsets to show the next coil
                horizontalOffset += 100.0
                verticalOffset = CGFloat(50.0)
                
                lastCoilName = nextCoilName
            }
            else
            {
                verticalOffset += CGFloat(elementHt!)
            }
            
            let oldFrame = nextField.frame
            let newFrame = NSRect(x: horizontalOffset - oldFrame.width / 2.0, y: verticalOffset, width: oldFrame.width, height: oldFrame.height)
            
            nextField.frame = newFrame
            
            // Show the border around the disk name (using isBordered is UGLY)
            let borderRect = NSRect(x: newFrame.origin.x - 2.0, y: newFrame.origin.y - 4.0, width: newFrame.width + 7.0, height: newFrame.height + 7.0)
            let borderPath = NSBezierPath(rect: borderRect)
            borderPath.stroke()
            
            let connectorPath = NSBezierPath()
            let connectorX = borderRect.origin.x + borderRect.width / 2.0
        
            // Draw the connector coming out the bottom of the disk
            connectorPath.move(to: NSPoint(x: connectorX, y: borderRect.origin.y))
            let endPoint = NSPoint(x: connectorX, y: borderRect.origin.y - CGFloat(connectorLength))
            connectorPath.line(to: endPoint)
            connectorPath.stroke()
            
            // Draw the connector coming out the top of the disk
            connectorPath.move(to: NSPoint(x: connectorX, y: borderRect.origin.y + borderRect.height))
             lastTopCircleCenter = NSPoint(x: connectorX, y: borderRect.origin.y + borderRect.height + CGFloat(connectorLength))
            connectorPath.line(to: lastTopCircleCenter)
            connectorPath.stroke()
            
            // Draw the node circle under the disk
            let nodeCircleRect = NSRect(x: endPoint.x - CGFloat(nodeDiameter) / 2.0, y: endPoint.y - CGFloat(nodeDiameter) / 2.0, width: CGFloat(nodeDiameter), height: CGFloat(nodeDiameter))
            let nodeCirclePath = NSBezierPath(ovalIn: nodeCircleRect)
            
            NSColor.white.set()
            nodeCirclePath.fill()
            
            NSColor.black.set()
            nodeCirclePath.stroke()
            
        }
        
        // Show the final top node over the final coil
        let nodeCircleRect = NSRect(x: lastTopCircleCenter.x - CGFloat(nodeDiameter) / 2.0, y: lastTopCircleCenter.y - CGFloat(nodeDiameter) / 2.0, width: CGFloat(nodeDiameter), height: CGFloat(nodeDiameter))
        let nodeCirclePath = NSBezierPath(ovalIn: nodeCircleRect)
        
        NSColor.white.set()
        nodeCirclePath.fill()
        
        NSColor.black.set()
        nodeCirclePath.stroke()
    }
    
    
    
    func fixFrameRect()
    {
        let requiredHeight = self.calculateCoilHeight() + 100.0
        
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
        var result = 0.0
        
        let sectArray = sections!
        
        if (elementHt == nil)
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
