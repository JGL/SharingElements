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
    
    init(pipelinesURL: URL, mtkView: MTKView, instance: String = "") {
        self.mtkView = mtkView
        super.init(pipelinesURL: pipelinesURL, instance: instance)
    }
        
    override func update() {
        super.update()
        updateAspect()
    }
    
    func updateAspect()
    {
        guard let mtkView = self.mtkView else { return }
        let width = Float(mtkView.drawableSize.width)
        let height = Float(mtkView.drawableSize.height)
        let aspect: Float = width/height
        set("Aspect", aspect)
        set("Resolution", [width, height, aspect])
    }
}
