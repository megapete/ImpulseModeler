//
//  AppDelegate.swift
//  ImpulseModeler
//
//  Created by PeterCoolAssHuber on 2016-10-26.
//  Copyright © 2016 Peter Huber. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var theController: AppController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

    // This function is required to use the Open Recent menu item as well as to launch the program from th Finder by double-clicking a file.
    func application(_ sender: NSApplication, openFile filename: String) -> Bool
    {
        let fixedFileName = (filename as NSString).expandingTildeInPath
        
        let url = URL(fileURLWithPath: fixedFileName, isDirectory: false)
        
        return theController.openModel(url)
    }
     
    
}

