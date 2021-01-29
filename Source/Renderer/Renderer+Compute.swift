//
//  Renderer+Compute.swift
//  Flocking
//
//  Created by Reza Ali on 1/28/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//
import Satin

extension Renderer {
    func setupMetalCompiler() {
        metalFileCompiler.onUpdate = { [unowned self] in
            self.setupLibrary()
        }
    }
    
    func setupLibrary() {
        do {
            var library: MTLLibrary?
            var source = try metalFileCompiler.parse(pipelinesURL.appendingPathComponent("Compute/Shaders.metal"))
            injectConstants(source: &source)
            library = try context.device.makeLibrary(source: source, options: .none)
                        
            if let particle = parseStruct(source: source, key: "Particle") {
                particleSystem.setParams([particle])
            }
            
            if let params = parseParameters(source: source, key: "ComputeUniforms") {
                params.label = "Compute"
                if let computeParams = self.computeParams {
                    computeParams.setFrom(params)
                }
                else {
                    computeParams = params
                }
                    
                computeUniforms = UniformBuffer(context: context, parameters: computeParams!)
            }
           
            if let lib = library {
                setupBufferCompute(lib)
                _updateInspector = true
            }
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func setupBufferCompute(_ library: MTLLibrary) {
        do {
            particleSystem.resetPipeline = try makeComputePipeline(library: library, kernel: "resetCompute")
            particleSystem.updatePipeline = try makeComputePipeline(library: library, kernel: "updateCompute")
            particleSystem.reset()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func updateBufferComputeUniforms() {
        computeParams?.set("Particle Count", particleCountParam.value)
        if let uniforms = computeUniforms {
            uniforms.update()
        }
    }
}
