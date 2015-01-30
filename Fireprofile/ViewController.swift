//
//  ViewController.swift
//  Fireprofile
//
//  Created by Folletto on 30/01/2015.
//  Copyright (c) 2015 Davide 'Folletto' Casali. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var profilesList: NSPopUpButton!
    
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        readProfiles();
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
            
        }
    }

    func readProfiles() {
        // ****************************************************************************************************
        // Let's read the folders inside the subdirectory "/profiles" as our profiles
        //
        
        var profilesPath = NSBundle.mainBundle().bundlePath.stringByDeletingLastPathComponent + "/profiles";
        
        profilesList.removeAllItems();
        
        var path: String? = "";
        var directoryEnumerator: NSDirectoryEnumerator? = NSFileManager().enumeratorAtPath(profilesPath);
        
        while let path = directoryEnumerator?.nextObject() as? String {
            //if directoryEnumerator?.fileAttributes?["fileType"] as String == NSFileTypeDirectory {
                profilesList.addItemsWithTitles([path]);
                directoryEnumerator?.skipDescendants();
            //}
        }
        
    }
    
    @IBAction func launchFirefox(sender: NSButton) {
        // ****************************************************************************************************
        // Let's launch the Firefox contained in the same folder as the app
        //
        
        // Preparing
        var appPath = NSBundle.mainBundle().bundlePath.stringByDeletingLastPathComponent;
        var firefoxArgs = appPath + "/profiles/" + profilesList.titleOfSelectedItem!;
        var firefoxPath = appPath + "/Firefox.app/Contents/MacOS/firefox";
        
        // Launching
        var firefox = NSTask();
        firefox.launchPath = firefoxPath;
        firefox.arguments = ["-profile", firefoxArgs];
        firefox.launch();
        
        NSApplication.sharedApplication().terminate(self);
    }
}

