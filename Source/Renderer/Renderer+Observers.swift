//
//  Renderer+Observers.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import AVFoundation
import Satin

extension Renderer {
    func updateBackground()
    {
        let c = self.bgColor.value
        let red = Double(c.x)
        let green = Double(c.y)
        let blue = Double(c.z)
        let alpha = Double(c.w)
        let clearColor: MTLClearColor = .init(red: red, green: green, blue: blue, alpha: alpha)
        self.renderer.clearColor = clearColor
    }
    
    func setupObservers() {
        let bgColorCb: (Float4Parameter, NSKeyValueObservedChange<Float>) -> Void = { [unowned self] _, _ in
            self.updateBackground()
        }
        observers.append(bgColor.observe(\.x, changeHandler: bgColorCb))
        observers.append(bgColor.observe(\.y, changeHandler: bgColorCb))
        observers.append(bgColor.observe(\.z, changeHandler: bgColorCb))
        observers.append(bgColor.observe(\.w, changeHandler: bgColorCb))
        
        observers.append(videoInput.observe(\StringParameter.value, options: [.new, .old]) { [unowned self] _, change in
            if let newValue = change.newValue, let oldValue = change.oldValue, newValue != oldValue {
                if let captureInput = self.captureInput {
                    self.captureSession.removeInput(captureInput)
                }
                
                guard let inputDevice = self.getInputDevice(self.videoInput.value) else { return }
                do {
                    self.captureInput = try AVCaptureDeviceInput(device: inputDevice)
                }
                catch {
                    print("AVCaptureDeviceInput Failed")
                    return
                }
                                
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .vga640x480
                if self.captureSession.canAddInput(self.captureInput!) {
                    self.captureSession.addInput(self.captureInput!)
                }
                self.captureSession.commitConfiguration()
            }
        })
    }
}
