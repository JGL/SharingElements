//
//  Renderer+LiveCode.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

#if os(macOS)
import AppKit

extension Renderer {
    func openEditor() {
        if let editorURL = UserDefaults.standard.url(forKey: "Editor") {
            openEditor(at: editorURL)
        }
        else {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.allowsMultipleSelection = false
            openPanel.canCreateDirectories = false
            openPanel.begin(completionHandler: { [unowned self] (result: NSApplication.ModalResponse) in
                if result == .OK {
                    if let editorUrl = openPanel.url {
                        UserDefaults.standard.set(editorUrl, forKey: "Editor")
                        self.openEditor(at: editorUrl)
                    }
                }
                openPanel.close()
            })
        }
    }

    func openEditor(at editorURL: URL) {
        do {
            try NSWorkspace.shared.open([self.pipelinesURL], withApplicationAt: editorURL, options: [], configuration: [:])
        } catch {
            print(error)
        }
    }
}

#endif
