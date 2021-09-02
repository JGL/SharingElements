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
            var librarySource = ""
            if let colorParams = self.colorParams {
                librarySource += colorParams.structString
            }
            if let massesParams = self.massesParams {
                librarySource += massesParams.structString
            }
            
            librarySource += try metalFileCompiler.parse(pipelinesURL.appendingPathComponent("Compute/Shaders.metal"))
            
            injectConstants(source: &librarySource)
            let library = try context.device.makeLibrary(source: librarySource, options: .none)
            
            if let params = parseStruct(source: librarySource, key: "Particle") {
                computeSystem.setParams([params])
            }
            
            if let computeParams = self.computeParams {
                computeParams.save(parametersURL.appendingPathComponent("Particles.json"))
            }
            
            if let params = parseParameters(source: librarySource, key: "ComputeUniforms") {
                params.label = "Compute"                
                params.load(parametersURL.appendingPathComponent("Particles.json"), append: false)
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
            let theta = degToRad(camera.fov / 2.0)
            let gridHeight = 2.0 * abs(camera.position.z) * tan(theta)
            let gridWidth = gridHeight * camera.aspect
            uniforms.parameters.set("Grid Size", simd_make_float2(gridWidth, gridHeight))
            uniforms.parameters.set("Count", particleCountValue)
            uniforms.parameters.set("Time", Float(currentTime))
            uniforms.parameters.set("Delta Time", Float(deltaTime))
            uniforms.parameters.set("Points", pointsMesh.points.count)
            uniforms.parameters.set("Lines", linesMesh.points.count/2)
            uniforms.update()
        }
        
        if let uniforms = self.colorUniforms {
            uniforms.update()
        }
        
        if let uniforms = self.massUniforms {
            uniforms.update()
        }
    }
    
}
