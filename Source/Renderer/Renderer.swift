//
//  Renderer.swift
//  Flocking
//
//  Created by Reza Ali on 1/28/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import Metal
import MetalKit

import Forge
import Satin
import Youi

class InstanceMaterial: LiveMaterial {}
class SpriteMaterial: LiveMaterial {}

class Renderer: Forge.Renderer, ObservableObject, MaterialDelegate {
    var assetsURL: URL {
        let url = Bundle.main.resourceURL!
        return url.appendingPathComponent("Assets")
    }
    
    var pipelinesURL: URL {
        assetsURL.appendingPathComponent("Pipelines")
    }
    
    lazy var startTime: CFAbsoluteTime = {
        CFAbsoluteTimeGetCurrent()
    }()
    
    var inspectorWindow: InspectorWindow?
    var _updateInspector: Bool = true
    var observers: [NSKeyValueObservation] = []
    
    var particleCountParam = IntParameter("Particle Count", 16384, .inputfield)
    var resetParam = BoolParameter("Reset", false)
    var pauseParam = BoolParameter("Pause", false)
        
    lazy var params: ParameterGroup = {
        let params = ParameterGroup("Controls")
        params.append(pauseParam)
        params.append(resetParam)        
        params.append(particleCountParam)
        return params
    }()
    
    lazy var scene: Object = {
        let scene = Object()
        scene.add(sprite)
        return scene
    }()
    
    lazy var context: Context = {
        Context(device, sampleCount, colorPixelFormat, depthPixelFormat, stencilPixelFormat)
    }()
    
    lazy var camera: OrthographicCamera = {
        OrthographicCamera()
    }()
    
    lazy var cameraController: OrthographicCameraController = {
        let controller = OrthographicCameraController(camera: camera, view: mtkView)
        return controller
    }()
    
    lazy var renderer: Satin.Renderer = {
        Satin.Renderer(context: context, scene: scene, camera: camera)
    }()
        
    lazy var particleSystem: BufferComputeSystem = {
        let compute = BufferComputeSystem(context: context, count: particleCountParam.value, feedback: true)
        compute.preCompute = { [unowned self] (computeEncoder: MTLComputeCommandEncoder, bufferOffset: Int) in
            var offset = bufferOffset
            if let uniforms = self.computeUniforms {
                computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: offset)
                offset += 1
            }
        }
        return compute
    }()
    
    var metalFileCompiler = MetalFileCompiler()
    var computeParams: ParameterGroup?
    var computeUniforms: UniformBuffer?
    
    lazy var spriteMaterial: SpriteMaterial = {
        let material = SpriteMaterial(pipelinesURL: pipelinesURL)
        material.depthWriteEnabled = false
        material.delegate = self
        return material
    }()
    
    lazy var sprite: Mesh = {
        let mesh = Mesh(geometry: PointGeometry(), material: spriteMaterial)
        mesh.label = "Sprite"
        mesh.cullMode = .none
        mesh.instanceCount = particleCountParam.value
        mesh.preDraw = { [unowned self] (renderEncoder: MTLRenderCommandEncoder) in
            if let buffer = self.particleSystem.getBuffer("Particle") {
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: VertexBufferIndex.Custom0.rawValue)
            }
            if let uniforms = self.computeUniforms {
                renderEncoder.setVertexBuffer(uniforms.buffer, offset: uniforms.offset, index: VertexBufferIndex.Custom1.rawValue)
            }
        }
        return mesh
    }()
    
    override func setupMtkView(_ metalKitView: MTKView) {
        metalKitView.isPaused = false
        metalKitView.sampleCount = 1
        metalKitView.depthStencilPixelFormat = .invalid
        metalKitView.preferredFramesPerSecond = 60
    }
    
    override func setup() {
        setupMetalCompiler()
        setupLibrary()
        setupObservers()
    }
        
    @objc override func updateAppearance() {
        var color = simd_float4(repeating: 1.0)
        if let _ = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            color = [0.075, 0.075, 0.075, 1.0]
        }
        else {
            color = [0.925, 0.925, 0.925, 1.0]
        }
        renderer.setClearColor(color)
    }
    
    override func update() {
        #if os(macOS)
            updateInspector()
        #endif
        
        let time = Float(CFAbsoluteTimeGetCurrent() - startTime)
        computeParams?.set("Time", time)
        spriteMaterial.set("Time", time)
        updateBufferComputeUniforms()
        cameraController.update()
    }
    
    override func draw(_ view: MTKView, _ commandBuffer: MTLCommandBuffer) {
        if !pauseParam.value {
            particleSystem.update(commandBuffer)
        }
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
    }
    
    override func resize(_ size: (width: Float, height: Float)) {
        let hw = size.width
        let hh = size.height
        camera.update(left: -hw, right: hw, bottom: -hh, top: hh, near: -100.0, far: 100.0)
        
        renderer.resize(size)
        let res: simd_float3 = [size.width, size.height, size.width / size.height]
        spriteMaterial.set("Resolution", res)
        computeParams?.set("Resolution", res)
    }
    

    
    // MARK: - Material Delegate

    func updated(material: Material) {
        print("Material Updated: \(material.label)")
        _updateInspector = true
    }
    
    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        if event.characters == "e" {
            openEditor()
        }
    }
}
