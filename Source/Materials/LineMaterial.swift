//
//  LineMaterial.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import MetalKit
import Satin

class LineMaterial: LiveMaterial {
    weak var mtkView: MTKView?
    weak var camera: PerspectiveCamera?
    
    init(pipelinesURL: URL, mtkView: MTKView?, instance: String = "") {
        self.mtkView = mtkView
        super.init(pipelinesURL: pipelinesURL, instance: instance)
        self.blending = .alpha
    }
                
    override func update(camera: Camera) {
        self.camera = camera as? PerspectiveCamera
    }
    
    func updateCamera() {
        guard let camera = self.camera else { return }
        let imagePlaneHeight = tanf(degToRad(camera.fov) * 0.5)
        let imagePlaneWidth = camera.aspect * imagePlaneHeight
                                
        let cameraRight = normalize(camera.worldRightDirection) * imagePlaneWidth
        let cameraUp = normalize(camera.worldUpDirection) * imagePlaneHeight
        let cameraForward = normalize(camera.viewDirection)
        let cameraDelta = camera.far - camera.near
        let cameraA = camera.far / cameraDelta
        let cameraB = (camera.far * camera.near) / cameraDelta
                
        set("Camera Position", camera.worldPosition)
        set("Camera Right", cameraRight)
        set("Camera Up", cameraUp)
        set("Camera Forward", cameraForward)
        
        if let view = mtkView {
            var dpr: Float = 0.0
            #if os(iOS)
            dpr = Float(view.contentScaleFactor)
            #elseif os(macOS)
            let pixelSize = view.convertToBacking(NSSize(width: 1, height: 1))
            dpr = Float(pixelSize.width)
            #endif
            let size = view.drawableSize
            set("Resolution", simd_make_float4(Float(size.width), Float(size.height), Float(size.width/size.height), dpr))
        }
        set("Near Far", simd_make_float2(camera.near, camera.far))
        set("Camera Depth", simd_make_float2(cameraA, cameraB))
    }
    
    override func bind(_ renderEncoder: MTLRenderCommandEncoder) {
        updateCamera()
        uniforms?.update()
        super.bind(renderEncoder)
        if let camera = self.camera {
            var view = camera.viewMatrix
            renderEncoder.setFragmentBytes(&view, length: MemoryLayout<float4x4>.size, index: FragmentBufferIndex.Custom0.rawValue)
        }
    }
}
