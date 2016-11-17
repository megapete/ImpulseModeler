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
    let textFieldHt = 17.0
    let connectorLength = 10.0
    let elementHt = 17.0 + 2.0 * 5.0
    let nodeDiameter = 5.0
    
    var sections:[PCH_DiskSection]? = nil
    var sectionFields:[NSTextField]? = nil
    
    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        
        NSColor.white.set()
        NSRectFill(self.bounds)

        // Drawing code here.
        
        NSColor.gray.set()
        let groundConnectionRect = NSRect(x: 67.5 - 15.0, y: self.bounds.height - 125.0, width: 30.0, height: 30.0)
        var path = NSBezierPath(roundedRect:groundConnectionRect , xRadius: 5.0, yRadius: 5.0)
        path.stroke()
        
        drawGroundAt(NSPoint(x: 67.5, y: self.bounds.height - 100.0))
        
        NSColor.gray.set()
        let impulseConnectionRect = NSOffsetRect(groundConnectionRect, 0.0, -50.0)
        path = NSBezierPath(roundedRect: impulseConnectionRect, xRadius: 5.0, yRadius: 5.0)
        path.stroke()
        
        drawLightningBoltAt(NSPoint(x:impulseConnectionRect.origin.x + impulseConnectionRect.width / 2.0, y:impulseConnectionRect.origin.y + impulseConnectionRect.height - 0.5))
        
    }
    
    func calculateCoilHeight() -> Double
    {
        var result = 0.0
        
        let sectArray = sections!
        
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
            
            currentCoilHt += elementHt
            
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
            nextField.isBordered = true
            nextField.isHidden = true
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
