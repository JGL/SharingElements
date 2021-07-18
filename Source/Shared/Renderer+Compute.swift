//
//  Renderer+Compute.swift
//  BodyElements macOS
//
//  Created by Reza Ali on 7/18/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import Metal
import Satin

extension Renderer {
    func setupMetalCompiler() {
        metalFileCompiler.onUpdate = { [unowned self] in
            self.setupLibrary()
        }
    }
    
    // MARK: Setup Library
    
    func setupLibrary() {
        print("Compiling Library")
        do {
            var librarySource = try metalFileCompiler.parse(pipelinesURL.appendingPathComponent("Compute/Shaders.metal"))
            injectConstants(source: &librarySource)
            let library = try context.device.makeLibrary(source: librarySource, options: .none)
            
            if let params = parseStruct(source: librarySource, key: "Particle") {
                computeSystem.setParams([params])
            }
            
            if let params = parseParameters(source: librarySource, key: "ComputeUniforms") {
                params.label = "Compute"
                computeUniforms = UniformBuffer(context: context, parameters: params)
                computeParams = params
            }
            
            _updateInspector = true
            
            setupBufferCompute(library)
        }
        catch let MetalFileCompilerError.invalidFile(fileURL) {
            print("Invalid File: \(fileURL.absoluteString)")
        }
        catch {
            print("Error: \(error)")
        }
    }
    
    func setupBufferCompute(_ library: MTLLibrary) {
        do {
            computeSystem.resetPipeline = try makeComputePipeline(library: library, kernel: "resetCompute")
            computeSystem.updatePipeline = try makeComputePipeline(library: library, kernel: "updateCompute")
            computeSystem.reset()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func updateBufferComputeUniforms() {
        if let uniforms = self.computeUniforms {
            uniforms.parameters.set("Count", particleCount.value)
            uniforms.update()
        }
    }
    
}
