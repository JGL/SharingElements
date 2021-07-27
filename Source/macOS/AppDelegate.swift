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
    var window: NSWindow?
    var viewController: Forge.ViewController!
    let renderer = Renderer()

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
        self.viewController.renderer = self.renderer
        guard let contentView = window.contentView else { return }

        view.frame = contentView.bounds
        view.autoresizingMask = [.width, .height]
        contentView.addSubview(view)

        window.setFrameAutosaveName("BodyElements")
        window.titlebarAppearsTransparent = true
        window.title = ""
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        self.viewController?.view.removeFromSuperview()
        self.viewController.renderer = nil
        self.viewController = nil
        self.renderer.cleanup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Toggle Inspector

    @IBAction func toggleInspector(_ sender: NSMenuItem) {
        self.renderer.toggleInspector()
    }
}
