//
//  AppDelegate.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import Cocoa
import MetalKit

import Forge

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var presetsMenu: NSMenu?
    
    var window: NSWindow?
    var viewController: Forge.ViewController!
    weak var renderer: Renderer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if fileExists(getDocumentsAssetsDirectoryUrl()) {
            copyDirectory(atPath: getResourceAssetsDirectoryUrl().path, toPath: getDocumentsAssetsDirectoryUrl().path)
        }
        else {
            copyDirectory(atPath: getResourceAssetsDirectoryUrl().path, toPath: getDocumentsAssetsDirectoryUrl().path, force: true)
        }

        let window = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: 100.0, y: 400.0), size: CGSize(width: 512, height: 512)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        self.window = window
        self.viewController = Forge.ViewController(nibName: .init("ViewController"), bundle: Bundle(for: Forge.ViewController.self))
        guard let view = self.viewController?.view else { return }
        let renderer = Renderer()
        self.viewController.renderer = renderer
        self.renderer = renderer
        guard let contentView = window.contentView else { return }

        view.frame = contentView.bounds
        view.autoresizingMask = [.width, .height]
        contentView.addSubview(view)

        window.setFrameAutosaveName("Sharing Elements")
        window.titlebarAppearsTransparent = true
        window.title = ""
        window.makeKeyAndOrderFront(nil)
        
        self.setupPresetsMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let renderer = self.renderer {
            renderer.cleanup()
        }
        self.viewController?.view.removeFromSuperview()
        self.viewController.renderer = nil
        self.viewController = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Toggle Inspector

    @IBAction func toggleInspector(_ sender: NSMenuItem) {
        guard let renderer = self.renderer else { return }
        renderer.toggleInspector()
    }
    
    // MARK: - Presets
    
    @IBAction func savePreset(_ sender: NSMenuItem) {
        guard let renderer = self.renderer else { return }
        let msg = NSAlert()
        msg.addButton(withTitle: "OK")
        msg.addButton(withTitle: "Cancel")
        msg.messageText = "Enter Preset Name"
        msg.informativeText = ""
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        input.stringValue = ""
        input.placeholderString = ""
        
        msg.accessoryView = input
        msg.window.initialFirstResponder = input
        let response: NSApplication.ModalResponse = msg.runModal()
        
        let presetName = input.stringValue
        if !presetName.isEmpty, response == NSApplication.ModalResponse.alertFirstButtonReturn {
            renderer.savePreset(presetName)
            self.setupPresetsMenu()
        }
    }
    
    @IBAction func savePresetAs(_ sender: NSMenuItem) {
        guard let renderer = self.renderer else { return }
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.title = "Save Preset"
        savePanel.allowedFileTypes = [""]
        savePanel.nameFieldStringValue = ""
        savePanel.begin(completionHandler: { (result: NSApplication.ModalResponse) in
            if result == .OK, let url = savePanel.url {
                renderer.save(url)
            }
            savePanel.close()
        })
    }
    
    @IBAction func openPreset(_ sender: NSMenuItem) {
        guard let renderer = self.renderer else { return }
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false
        openPanel.begin(completionHandler: { (result: NSApplication.ModalResponse) in
            if result == .OK {
                if let url = openPanel.url {
                    renderer.load(url)
                }
            }
            openPanel.close()
        })
    }
    
    func setupPresetsMenu() {
        guard let menu = presetsMenu else { return }
        var activePresetName = ""
        for item in menu.items {
            if item.state == .on {
                activePresetName = item.title
                break
            }
        }
        menu.removeAllItems()
        menu.addItem(withTitle: "Default", action: #selector(self.loadPreset), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        let fm = FileManager.default
        let presetsUrl = getDocumentsAssetsDirectoryUrl("Presets")
        if fm.fileExists(atPath: presetsUrl.path) {
            do {
                let presets = try fm.contentsOfDirectory(atPath: presetsUrl.path).sorted()
                for preset in presets {
                    let presetUrl = presetsUrl.appendingPathComponent(preset)
                    var isDirectory: ObjCBool = false
                    if fm.fileExists(atPath: presetUrl.path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            let item = NSMenuItem(title: preset, action: #selector(self.loadPreset), keyEquivalent: "")
                            if preset == activePresetName {
                                item.state = .on
                            }
                            menu.addItem(item)
                        }
                    }
                }
            }
            catch {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc func loadPreset(_ sender: NSMenuItem) {
        guard let renderer = self.renderer else { return }
        
        renderer.loadPreset(sender.title)
                    
        guard let menu = presetsMenu else { return }
        for item in menu.items {
            item.state = .off
        }
        sender.state = .on
    }
}
