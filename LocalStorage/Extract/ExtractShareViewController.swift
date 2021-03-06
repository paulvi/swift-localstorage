//
//  ExtractShareViewController.swift
//  Zip
//
//  Created by Günther Eberl on 27.02.18.
//  Copyright © 2018 Günther Eberl. All rights reserved.
//

import UIKit
import os.log
import Social


// Logger configuration.
let logExtractExtension = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "extract-extension")


class ExtractShareViewController: SLComposeServiceViewController {
    
    var fileUrl: URL? = nil
    
    override func viewDidLoad() {
        os_log("viewDidLoad", log: logExtractExtension, type: .debug)
        super.viewDidLoad()
        
        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
            for provider in item.attachments! {
                // Search for "Uniform Type Identifiers Reference" for a full list of UTIs.
                // Anything that is a file should contain at least "public.file-url" + "public.data".
                // So let anything through here. Decide later what this thing actually is and if it can be extracted.
                if provider.hasItemConformingToTypeIdentifier("public.data") {
                    provider.loadItem(forTypeIdentifier: "public.data",
                                      options: [:],
                                      completionHandler: self.loadFile)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        os_log("viewDidAppear", log: logExtractExtension, type: .debug)
        super.viewDidAppear(animated)
        let openingPlaceholder = NSLocalizedString("extract-opening-placeholder",
                                                   value: "Opening in Local Storage ...",
                                                   comment: "Put on TextView, shouldn't be visible though, too fast")
        self.textView.text = openingPlaceholder
    }
    
    override func viewWillAppear(_ animated: Bool) {
        os_log("viewWillAppear", log: logExtractExtension, type: .debug)
        super.viewWillAppear(animated)
        let openButton = NSLocalizedString("extract-open-button",
                                           value: "Open",
                                           comment: "Put on dialog top right")
        self.navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = openButton  // Standard "Post"
    }
    
    func loadFile(coding: NSSecureCoding?, error: Error!) {
        os_log("loadFile", log: logExtractExtension, type: .debug)
        
        if error != nil {
            os_log("%@", log: logExtractExtension, type: .error, error.localizedDescription)
            return
        }
        
        if coding != nil {
            if let url = coding as? URL {
                self.fileUrl = self.copyToAppGroupFolder(srcUrl: url)
                if self.fileUrl != nil {
                    self.didSelectPost()  // Hit the "Open" button right away
                }
            }
        }
    }
    
    func removeFileIfExist(path: String) {
        os_log("removeFileIfExist", log: logExtractExtension, type: .debug)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
                os_log("Removed file '%@'", log: logExtractExtension, type: .debug, path)
            } catch {
                os_log("%@", log: logExtractExtension, type: .error, error.localizedDescription)
            }
        }
    }
    
    func copyToAppGroupFolder(srcUrl: URL) -> URL? {
        os_log("copyToAppGroupFolder", log: logExtractExtension, type: .debug)
        
        let appGroupName: String = "group.se.eberl.localstorage"
        let fileManager = FileManager.default
        if let destDirUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
            
            let destUrl = destDirUrl.appendingPathComponent(srcUrl.lastPathComponent)
            removeFileIfExist(path: destUrl.path)  // copyItem doesn't overwrite but fails if that file exists already

            do {
                try fileManager.copyItem(at: srcUrl, to: destUrl)
                return destUrl
            } catch {
                os_log("Copying failed: %@", log: logExtractExtension, type: .error, error.localizedDescription)
            }
        }
        return nil
    }
    
    override func isContentValid() -> Bool {
        if self.fileUrl == nil {
            return false
        } else {
            return true
        }
    }
    
    @objc func openURL(_ url: URL) {
        // Function needed for hack in self.openMainApp().
        return
    }
    
    func openMainApp(path: String) {
        os_log("openMainApp", log: logExtractExtension, type: .debug)
        
        // Hack to open main app from a share extension from https://stackoverflow.com/a/28037297/8137043
        // This may break in any new version on iOS.
        
        let selector = #selector(openURL(_:))

        var responder: UIResponder? = self as UIResponder
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                let filePathPercentEncoded: String = path.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let appUrl: URL = URL(string: "localstorage://actionextension?extract=" + filePathPercentEncoded)!
                responder!.perform(selector, with: appUrl)
                return
            }
            responder = responder?.next
        }
    }

    override func didSelectPost() {
        os_log("didSelectPost", log: logExtractExtension, type: .debug)
        if self.fileUrl != nil {
            self.openMainApp(path: self.fileUrl!.path)
        }
        super.didSelectPost()
    }

}
