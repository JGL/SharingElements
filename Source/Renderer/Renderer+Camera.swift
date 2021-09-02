//
//  Renderer+Video.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import AVFoundation
import Vision

extension Renderer {
    func setupCamera() {
        setupInputList()
        setupTextureCache()
        setupPermissions()
    }

    func stopCamera() {
        if let captureInput = self.captureInput {
            captureSession.removeInput(captureInput)
        }
        captureSession.stopRunning()
        outputData.setSampleBufferDelegate(nil, queue: nil)
    }

    func setupInputList() {
        let inputs = getInputDeviceNames()
        if videoInput.value.count == 0, let firstInput = inputs.first {
            videoInput.value = firstInput
        }
    }

    func setupPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
                if granted {
                    self.setupCapture()
                }
            }
        case .denied:
            AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
                if granted {
                    self.setupCapture()
                }
            }
            return
        case .restricted: // The user can't grant access due to restrictions.
            return
        default:
            return
        }
    }

    func setupCapture() {
        guard let inputDevice = getInputDevice(videoInput.value) else { return }

        do {
            captureInput = try AVCaptureDeviceInput(device: inputDevice)
        }
        catch {
            print("AVCaptureDeviceInput Failed")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        if captureSession.canAddInput(captureInput!) {
            captureSession.addInput(captureInput!)
        }
    
        captureSessionQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
        outputData.setSampleBufferDelegate(self, queue: captureSessionQueue)
        
        if captureSession.canAddOutput(outputData) {
            captureSession.addOutput(outputData)
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    @objc public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // create camera texture for displaying
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer")
            return
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        if fakePose.value {
            linesMesh.visible = true
            pointsMesh.visible = true
            linesMesh.points = fakeLines
            pointsMesh.points = fakePoints
        }
        else if updatePose.value {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, options: [:])
            do {
                try handler.perform([bodyPoseRequest])
                if let observations = bodyPoseRequest.results, observations.count > 0 {
                    let observation = observations[0]
                    do {
                        let bodyPoints = try observation.recognizedPoints(.all)
                        linesMesh.visible = true
                        pointsMesh.visible = true
                        
                        var points: [simd_float3] = []
                        var lines: [simd_float3] = []
                        
                            for (key, point) in bodyPoints {
                            if let mesh = bodyMeshes[key] {
                                if point.location.y < 0.99999 {
                                    var pos = VNImagePointForNormalizedPoint(point.location, width, height)
                                    pos.x = flipVideo.value ? CGFloat(width) - pos.x : pos.x
                                    let pt = simd_make_float3(Float(pos.x) - Float(width) * 0.5, Float(pos.y) - Float(height) * 0.5, 0.0)
                                    mesh.visible = true
                                    points.append(pt)
                                    mesh.position = pt
                                }
                                else {
                                    mesh.visible = false
                                }
                            }
                        }
                        
                        if leftHipMesh.visible, rightHipMesh.visible {
                            let lh = leftHipMesh.position
                            let rh = rightHipMesh.position
                            let dir = simd_normalize(lh - rh) * hipExtension.value
                            leftHipMesh.position = leftHipMesh.position + dir
                            rightHipMesh.position = rightHipMesh.position - dir
                        }                        
                        
                        pointsMesh.points = points

                        if leftWristMesh.visible, leftElbowMesh.visible {
                            lines.append(leftWristMesh.position)
                            lines.append(leftElbowMesh.position)
                        }

                        if leftElbowMesh.visible, leftShoulderMesh.visible {
                            lines.append(leftElbowMesh.position)
                            lines.append(leftShoulderMesh.position)
                        }

                        if leftShoulderMesh.visible, neckMesh.visible {
                            lines.append(leftShoulderMesh.position)
                            lines.append(neckMesh.position)
                        }

                        if leftShoulderMesh.visible, leftHipMesh.visible {
                            lines.append(leftShoulderMesh.position)
                            lines.append(leftHipMesh.position)
                        }

                        if leftHipMesh.visible, leftKneeMesh.visible {
                            lines.append(leftHipMesh.position)
                            lines.append(leftKneeMesh.position)
                        }

                        if leftKneeMesh.visible, leftAnkleMesh.visible {
                            lines.append(leftKneeMesh.position)
                            lines.append(leftAnkleMesh.position)
                        }

                        if leftHipMesh.visible, rootMesh.visible {
                            lines.append(leftHipMesh.position)
                            lines.append(rootMesh.position)
                        }

                        if neckMesh.visible, noseMesh.visible {
                            lines.append(neckMesh.position)
                            lines.append(noseMesh.position)
                        }

                        if neckMesh.visible, rightShoulderMesh.visible {
                            lines.append(neckMesh.position)
                            lines.append(rightShoulderMesh.position)
                        }

                        if rightShoulderMesh.visible, rightElbowMesh.visible {
                            lines.append(rightShoulderMesh.position)
                            lines.append(rightElbowMesh.position)
                        }

                        if rightElbowMesh.visible, rightWristMesh.visible {
                            lines.append(rightElbowMesh.position)
                            lines.append(rightWristMesh.position)
                        }

                        if rightShoulderMesh.visible, rightHipMesh.visible {
                            lines.append(rightShoulderMesh.position)
                            lines.append(rightHipMesh.position)
                        }

                        if rightHipMesh.visible, rightKneeMesh.visible {
                            lines.append(rightHipMesh.position)
                            lines.append(rightKneeMesh.position)
                        }

                        if rightKneeMesh.visible, rightKneeMesh.visible {
                            lines.append(rightKneeMesh.position)
                            lines.append(rightAnkleMesh.position)
                        }

                        if rightHipMesh.visible, rootMesh.visible {
                            lines.append(rightHipMesh.position)
                            lines.append(rootMesh.position)
                        }

                        if neckMesh.visible, rootMesh.visible {
                            lines.append(neckMesh.position)
                            lines.append(rootMesh.position)
                        }
                        
                        if leftShoulderMesh.visible, rightShoulderMesh.visible,
                           leftHipMesh.visible, rightHipMesh.visible {
                            lines.append(leftShoulderMesh.position)
                            lines.append(rightHipMesh.position)
                            lines.append(rightShoulderMesh.position)
                            lines.append(leftHipMesh.position)
                            
                            let quarter = simd_float3(repeating: 0.25)
                            let half = simd_float3(repeating: 0.5)
                            let threeQuarters = simd_float3(repeating: 0.75)
                            
                            lines.append(simd_mix(rightShoulderMesh.position, rightHipMesh.position, quarter))
                            lines.append(simd_mix(leftShoulderMesh.position, leftHipMesh.position, quarter))
                            lines.append(simd_mix(rightShoulderMesh.position, rightHipMesh.position, half))
                            lines.append(simd_mix(leftShoulderMesh.position, leftHipMesh.position, half))
                            lines.append(simd_mix(rightShoulderMesh.position, rightHipMesh.position, threeQuarters))
                            lines.append(simd_mix(leftShoulderMesh.position, leftHipMesh.position, threeQuarters))
                        }

                        
                        linesMesh.points = lines

//                        print(bodyPoints)
                    }
                    catch {
                        linesMesh.visible = false
                        pointsMesh.visible = false
//                    print("didn't recognize any points")
                    }
                }
                else {
                    linesMesh.visible = false
                    pointsMesh.visible = false
//                print("didn't detect any bodies")
                }
            }
            catch {
                print(error.localizedDescription)
            }
        }
        
        if showVideo.value {
            var cvTextureOut: CVMetalTexture?

            let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                   videoTextureCache.unsafelyUnwrapped,
                                                                   imageBuffer,
                                                                   nil,
                                                                   context.colorPixelFormat,
                                                                   width,
                                                                   height,
                                                                   0,
                                                                   &cvTextureOut)

            guard result == kCVReturnSuccess, let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
                print("Failed To Create Texture From Image")
                return
            }

            videoTexture = inputTexture
            cameraTexture = cvTexture
        }
    }

    func getInputDevices() -> [AVCaptureDevice] {
        if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
            return discoverySession.devices
        }
        else {
            return AVCaptureDevice.devices()
        }
    }

    func processDeviceName(_ name: String) -> String {
        var result = name
        result = result.replacingOccurrences(of: "(Built-in)", with: "")
        result = result.replacingOccurrences(of: "Camera", with: "")
        return result
    }

    func getInputDeviceNames() -> [String] {
        var results: [String] = []
        let devices = getInputDevices()
        for device in devices {
            results.append(processDeviceName(device.localizedName))
        }
        return results
    }

    func getInputDevice(_ name: String) -> AVCaptureDevice? {
        let devices = getInputDevices()
        if devices.count == 0 { return nil }
        for device in devices {
            if processDeviceName(device.localizedName) == videoInput.value {
                return device
            }
        }
        return nil
    }

    func setupTextureCache() {
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, context.device, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache")
        }
        else {
            videoTextureCache = textCache
        }
    }
}
