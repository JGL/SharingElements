//
//  PointMesh.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import MetalKit
import Satin

class PointMesh: DataMesh {
    var verticesBuffer: MTLBuffer?
    var points: [simd_float3] {
        didSet {
            updateData = true
        }
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    init(points: [simd_float3], material: Material) {
        self.points = points
        super.init(geometry: PointGeometry(), material: material)
        self.cullMode = .none
        self.preDraw = { [unowned self] renderEncoder in
            renderEncoder.setVertexBuffer(self.verticesBuffer, offset: 0, index: VertexBufferIndex.Custom0.rawValue)
        }
    }
    
    override func _setup()
    {
        guard let context = self.context else { return }
        instanceCount = points.count
        guard instanceCount > 0 else { return }
        verticesBuffer = context.device.makeBuffer(bytes: &points, length: MemoryLayout<simd_float3>.stride * points.count)
    }
}
