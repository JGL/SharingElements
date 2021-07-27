//
//  Renderer.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import AVFoundation
import Metal
import MetalKit
import Vision

import Forge
import Satin
import Youi

class SpriteMaterial: LiveMaterial {}

class Renderer: Forge.Renderer, MaterialDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Elements
    var bodyComposition: Elements?
    
    // MARK: - Particles
    
    var metalFileCompiler = MetalFileCompiler()

    lazy var particleCount: IntParameter = {
        let param = IntParameter("Particle Count", 4096, .inputfield) { value in
            self.spriteMesh.instanceCount = value
            self.computeSystem.count = value
        }
        return param
    }()
    
    lazy var computeSystem: BufferComputeSystem = {
        let compute = BufferComputeSystem(context: context, count: particleCount.value, feedback: false)
        compute.preCompute = { [unowned self] (computeEncoder: MTLComputeCommandEncoder, bufferOffset: Int) in
            var offset = bufferOffset
            if let uniforms = self.computeUniforms {
                computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: offset)
                offset += 1
            }
            
            computeEncoder.setBuffer(self.linesMesh.pointsBuffer, offset: 0, index: offset)
            offset += 1
            
            if let uniforms = self.colorUniforms {
                computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: offset)
                offset += 1
            }
            
            if let uniforms = self.massUniforms {
                computeEncoder.setBuffer(uniforms.buffer, offset: uniforms.offset, index: offset)
                offset += 1
            }
            
            
        }
        return compute
    }()
    
    var computeParams: ParameterGroup?
    var computeUniforms: UniformBuffer?
    var colorUniforms: UniformBuffer?
    var massUniforms: UniformBuffer?
    
    lazy var spriteMaterial: SpriteMaterial = {
        let material = SpriteMaterial(pipelinesURL: pipelinesURL)
        material.delegate = self
        material.blending = .additive
        material.depthWriteEnabled = false
        return material
    }()
    
    lazy var spriteMesh: Mesh = {
        let mesh = Mesh(geometry: PointGeometry(), material: spriteMaterial)
        mesh.instanceCount = particleCount.value
        mesh.preDraw = { [unowned self] (renderEncoder: MTLRenderCommandEncoder) in
            if let buffer = self.computeSystem.getBuffer("Particle") {
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: VertexBufferIndex.Custom0.rawValue)
            }
        }
        return mesh
    }()
    
    // MARK: - Vision Body Pose
    
    lazy var bodyPoseRequest: VNDetectHumanBodyPoseRequest = {
        VNDetectHumanBodyPoseRequest()
    }()
    
    // MARK: - Camera Feed

    lazy var videoInput: StringParameter = {
        let inputs = getInputDeviceNames()
        let param = StringParameter("Video Input", "", inputs, .dropdown)
        return param
    }()
    
    var videoTexture: MTLTexture?
    var videoTextureCache: CVMetalTextureCache?
    
    var captureSession = AVCaptureSession()
    var captureInput: AVCaptureDeviceInput?
    var captureSessionQueue: DispatchQueue!
    
    // Needed to make sure the MTLTexture doesn't go out of scope before the texture is read
    var cameraTexture: CVMetalTexture?
    
    lazy var outputData: AVCaptureVideoDataOutput = {
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as AnyObject,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        return out
    }()
    
    // MARK: - Paths
    
    var dataURL: URL {
        getDocumentsAssetsDirectoryUrl("Data")
    }
    
    var pipelinesURL: URL {
        getDocumentsAssetsDirectoryUrl("Pipelines")
    }
    
    var parametersURL: URL {
        return getDocumentsAssetsDirectoryUrl("Parameters")
    }
    
    // MARK: - UI
    
    var paramKeys: [String] {
        return [
            "Controls",
            "Colors",
            "Masses",
            "Video Material",
            "Point Material",
            "Line Material",
            "Sprite Material",
            "Particles"
        ]
    }
    
    var params: [String: ParameterGroup?] {
        return [
            "Controls": appParams,
            "Colors": colorParams,
            "Masses": massesParams,
            "Video Material": videoMaterial.parameters,
            "Point Material": pointMaterial.parameters,
            "Line Material": lineMaterial.parameters,
            "Sprite Material": spriteMaterial.parameters,
            "Particles": computeParams
        ]
    }
    
    var inspectorWindow: InspectorWindow?
    var _updateInspector: Bool = true
    var observers: [NSKeyValueObservation] = []
    
    // MARK: - Parameters
    
    var bgColor = Float4Parameter("Background", [1, 1, 1, 1], .colorpicker)
    var fullscreen = BoolParameter("Fullscreen", false, .toggle)
    var updatePose = BoolParameter("Update Pose", true, .toggle)
    var fakePose = BoolParameter("Fake Pose", false, .toggle)
    
    var fakeLines: [simd_float3] = [
        simd_make_float3(-261.898254, 173.549255, 0.000000),
        simd_make_float3(-151.697144, 121.546570, 0.000000),
        simd_make_float3(-151.697144, 121.546570, 0.000000),
        simd_make_float3(-54.100342, 211.511841, 0.000000),
        simd_make_float3(-54.100342, 211.511841, 0.000000),
        simd_make_float3(22.713623, 207.329163, 0.000000),
        simd_make_float3(-54.100342, 211.511841, 0.000000),
        simd_make_float3(-29.878479, -27.130432, 0.000000),
        simd_make_float3(-29.878479, -27.130432, 0.000000),
        simd_make_float3(-35.814880, -198.462769, 0.000000),
        simd_make_float3(-35.814880, -198.462769, 0.000000),
        simd_make_float3(-36.862549, -347.708466, 0.000000),
        simd_make_float3(-29.878479, -27.130432, 0.000000),
        simd_make_float3(17.489075, -27.816345, 0.000000),
        simd_make_float3(22.713623, 207.329163, 0.000000),
        simd_make_float3(22.052124, 311.769531, 0.000000),
        simd_make_float3(22.713623, 207.329163, 0.000000),
        simd_make_float3(99.527588, 203.146423, 0.000000),
        simd_make_float3(99.527588, 203.146423, 0.000000),
        simd_make_float3(171.808228, 94.605774, 0.000000),
        simd_make_float3(171.808228, 94.605774, 0.000000),
        simd_make_float3(279.950195, 116.137695, 0.000000),
        simd_make_float3(99.527588, 203.146423, 0.000000),
        simd_make_float3(64.856567, -28.502197, 0.000000),
        simd_make_float3(64.856567, -28.502197, 0.000000),
        simd_make_float3(88.286133, -194.944397, 0.000000),
        simd_make_float3(88.286133, -194.944397, 0.000000),
        simd_make_float3(93.564209, -352.168213, 0.000000),
        simd_make_float3(64.856567, -28.502197, 0.000000),
        simd_make_float3(17.489075, -27.816345, 0.000000)
    ]
    
    var fakePoints: [simd_float3] = [
        simd_make_float3(68.444580, 311.264648, 0.000000),
        simd_make_float3(-35.814880, -198.462769, 0.000000),
        simd_make_float3(64.856567, -28.502197, 0.000000),
        simd_make_float3(99.527588, 203.146423, 0.000000),
        simd_make_float3(22.052124, 311.769531, 0.000000),
        simd_make_float3(-151.697144, 121.546570, 0.000000),
        simd_make_float3(-29.878479, -27.130432, 0.000000),
        simd_make_float3(-54.100342, 211.511841, 0.000000),
        simd_make_float3(93.564209, -352.168213, 0.000000),
        simd_make_float3(-10.444885, 316.963684, 0.000000),
        simd_make_float3(171.808228, 94.605774, 0.000000),
        simd_make_float3(17.489075, -27.816345, 0.000000),
        simd_make_float3(-261.898254, 173.549255, 0.000000),
        simd_make_float3(-36.862549, -347.708466, 0.000000),
        simd_make_float3(11.540833, 331.097412, 0.000000),
        simd_make_float3(279.950195, 116.137695, 0.000000),
        simd_make_float3(40.453857, 331.823853, 0.000000),
        simd_make_float3(22.713623, 207.329163, 0.000000),
        simd_make_float3(88.286133, -194.944397, 0.000000)
    ]

    lazy var updateParticles: BoolParameter = {
        return BoolParameter("Update Particles", true, .toggle)
    }()
    
    lazy var resetParticles: BoolParameter = {
        let param = BoolParameter("Reset Particles", false, .button) { value in
            if value {
                self.computeSystem.reset()
            }
        }
        return param
    }()
    
    
    lazy var showVideo: BoolParameter = {
        let param = BoolParameter("Show Video", true, .toggle) { value in
            self.videoMesh.visible = value
        }
        return param
    }()
    
    lazy var flipVideo: BoolParameter = {
        BoolParameter("Flip Video", true, .toggle)
    }()
    
    lazy var showPoints: BoolParameter = {
        let param = BoolParameter("Show Points", true, .toggle) { value in
            self.pointsContainer.visible = value
        }
        return param
    }()
    
    lazy var showLines: BoolParameter = {
        let param = BoolParameter("Show Lines", true, .toggle) { value in
            self.linesContainer.visible = value
        }
        return param
    }()
    
    lazy var showParticles: BoolParameter = {
        let param = BoolParameter("Show Particles", true, .toggle) { value in
            self.spriteMesh.visible = value
        }
        return param
    }()
    
    lazy var appParams: ParameterGroup = {
        let params = ParameterGroup("Controls")
        params.append(bgColor)
        params.append(fullscreen)
        params.append(videoInput)
        params.append(showVideo)
        params.append(flipVideo)
        params.append(updatePose)
        params.append(fakePose)
        params.append(showPoints)
        params.append(showLines)
        params.append(particleCount)
        params.append(resetParticles)
        params.append(updateParticles)
        params.append(showParticles)
        return params
    }()
    
    var colorParams: ParameterGroup?
    var massesParams: ParameterGroup?
    
    // MARK: - Graphics
    
    lazy var videoMaterial: BasicTextureMaterial = {
        let mat = BasicTextureMaterial(texture: self.videoTexture)
        mat.depthWriteEnabled = false
        mat.delegate = self
        return mat
    }()

    lazy var lineMaterial: LineMaterial = {
        let mat = LineMaterial(pipelinesURL: pipelinesURL, mtkView: mtkView)
        mat.delegate = self
        return mat
    }()
    
    lazy var pointMaterial: PointMaterial = {
        let mat = PointMaterial(pipelinesURL: pipelinesURL)
        mat.delegate = self
        return mat
    }()
    
    lazy var pointsContainer: Object = {
       let container = Object()
        container.label = "Points Container"
        container.add(pointsMesh)
        return container
    }()
    
    lazy var pointsMesh: PointMesh = {
        let mesh = PointMesh(points: fakePoints, material: pointMaterial)
        mesh.label = "Points"
        return mesh
    }()
    
    lazy var linesContainer: Object = {
       let container = Object()
        container.label = "Lines Container"
        container.add(linesMesh)
        return container
    }()
    
    lazy var linesMesh: LineMesh = {
        let mesh = LineMesh(points: fakeLines, material: lineMaterial)
        mesh.label = "Lines"
        return mesh
    }()
    
    var pointGeometry = PointGeometry()
    
    lazy var rightEarMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([1, 0, 0, 1], 25, .alpha))
        mesh.label = "Right Ear"
        return mesh
    }()
    
    lazy var rightEyeMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 0, 1], 25, .alpha))
        mesh.label = "Right Eye"
        return mesh
    }()
    
    lazy var leftEyeMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 0, 1, 1], 25, .alpha))
        mesh.label = "Left Eye"
        return mesh
    }()
    
    lazy var leftEarMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([1, 0, 1, 1], 25, .alpha))
        mesh.label = "Left Ear"
        return mesh
    }()
    
    lazy var noseMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([1, 1, 0, 1], 25, .alpha))
        mesh.label = "Nose"
        return mesh
    }()
    
    lazy var neckMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Neck"
        return mesh
    }()
    
    lazy var leftShoulderMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Shoulder"
        return mesh
    }()
    
    lazy var leftElbowMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Elbow"
        return mesh
    }()
    
    lazy var leftWristMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Wrist"
        return mesh
    }()
    
    lazy var leftHipMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Hip"
        return mesh
    }()
    
    lazy var leftKneeMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Knee"
        return mesh
    }()
    
    lazy var leftAnkleMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Left Ankle"
        return mesh
    }()
    
    lazy var rightShoulderMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Shoulder"
        return mesh
    }()
    
    lazy var rightElbowMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Elbow"
        return mesh
    }()
    
    lazy var rightWristMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Wrist"
        return mesh
    }()
    
    lazy var rightHipMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Hip"
        return mesh
    }()
    
    lazy var rightKneeMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Knee"
        return mesh
    }()
    
    lazy var rightAnkleMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Right Ankle"
        return mesh
    }()
    
    lazy var rootMesh: Mesh = {
        let mesh = Mesh(geometry: pointGeometry, material: BasicPointMaterial([0, 1, 1, 1], 25, .alpha))
        mesh.label = "Root Mesh"
        return mesh
    }()
    
    lazy var videoMesh: Mesh = {
        let mesh = Mesh(geometry: PlaneGeometry(size: (1, 1), plane: .xy), material: videoMaterial)
        mesh.label = "Video"
        mesh.cullMode = .none
        return mesh
    }()

    lazy var bodyMeshes: [VNHumanBodyPoseObservation.JointName: Mesh] = {
        [
            .nose: noseMesh,
            .neck: neckMesh,
            .root: rootMesh,
            .rightEar: rightEarMesh,
            .rightEye: rightEyeMesh,
            .rightShoulder: rightShoulderMesh,
            .rightElbow: rightElbowMesh,
            .rightWrist: rightWristMesh,
            .rightHip: rightHipMesh,
            .rightKnee: rightKneeMesh,
            .rightAnkle: rightAnkleMesh,
            .leftEar: leftEarMesh,
            .leftEye: leftEyeMesh,
            .leftShoulder: leftShoulderMesh,
            .leftElbow: leftElbowMesh,
            .leftWrist: leftWristMesh,
            .leftHip: leftHipMesh,
            .leftKnee: leftKneeMesh,
            .leftAnkle: leftAnkleMesh
        ]
    }()
    
    lazy var scene: Object = {
        let scene = Object()
        scene.add(videoMesh)
        scene.add(pointsContainer)
        scene.add(linesContainer)
        scene.add(spriteMesh)
        return scene
    }()
    
    lazy var context: Context = {
        Context(device, sampleCount, colorPixelFormat, depthPixelFormat, stencilPixelFormat)
    }()
    
    lazy var camera: PerspectiveCamera = {
        let camera = PerspectiveCamera()
        camera.position = simd_make_float3(0.0, 0.0, 1000.0)
        camera.near = 0.01
        camera.far = 4000.0
        return camera
    }()
    
    lazy var cameraController: PerspectiveCameraController = {
        let cc = PerspectiveCameraController(camera: camera, view: mtkView)
        cc.zoomScalar = 100.0
        cc.mouseDeltaSensitivity = 50.0
        cc.translationScalar = 1.0
        return cc
    }()
    
    lazy var renderer: Satin.Renderer = {
        Satin.Renderer(context: context, scene: scene, camera: camera)
    }()
    
    lazy var startTime: CFTimeInterval = {
        CFAbsoluteTimeGetCurrent()
    }()
    
    lazy var lastTime: CFTimeInterval = {
        CFAbsoluteTimeGetCurrent()
    }()
    
    lazy var currentTime: CFTimeInterval = {
        CFAbsoluteTimeGetCurrent()
    }()
    
    var deltaTime: CFTimeInterval =  0.0
    
    override func setupMtkView(_ metalKitView: MTKView) {
        metalKitView.sampleCount = 1
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.preferredFramesPerSecond = 60
    }
    
    override init() {
        // do stuff here
    }
    
    deinit {
        cleanup()
    }
    
    func setupData()
    {
        let decoder = JSONDecoder()
        var data: Data
        do{
            data = try Data(contentsOf: dataURL.appendingPathComponent("Elements.json"))
        }
        catch {
            print("Failed to load data file")
            return
        }
        
        do {
            let bodyComposition = try decoder.decode(Elements.self, from: data)
            let colorParams = ParameterGroup("Colors")
            let massParams = ParameterGroup("Masses")
            self.bodyComposition = bodyComposition
            for element in bodyComposition.elements {
                colorParams.append(Float4Parameter(element.name.titleCase, [1.0, 1.0, 1.0, 1.0], .colorpicker))
                massParams.append(FloatParameter(element.name.titleCase + " Mass", element.mass/100.0, .inputfield))
            }
            self.colorParams = colorParams
            self.massesParams = massParams
            
            self.colorUniforms = UniformBuffer(context: context, parameters: colorParams)
            self.massUniforms = UniformBuffer(context: context, parameters: massParams)
        } catch {
            print("Failed to decode JSON")
        }
    }
    
    override func setup() {
        setupData()
        setupCamera()
        setupMetalCompiler()
        setupLibrary()
        setupObservers()
        load()
    }
    
    public func cleanup() {
        save()
        stopCamera()
    }
    
    func getTime() -> CFTimeInterval {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func updateTime() {
        currentTime = getTime()
        deltaTime = currentTime - lastTime
        lastTime = currentTime
    }

    func updateFullscreen()
    {
        if let window = self.mtkView.window {
            if fullscreen.value, !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                print("toggled on fullscreen")
            }
            else if !fullscreen.value, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                print("toggled off fullscreen")
            }
        }
    }
    
    override func update() {
        updateFullscreen()
        updateTime()
        cameraController.update()
        updateBufferComputeUniforms()
        updateInspector()
        
        if let texture = videoTexture, videoMesh.scale.x != Float(texture.width), videoMesh.scale.y != Float(texture.height) {
            videoMesh.scale = simd_make_float3((flipVideo.value ? -1.0 : 1.0) * Float(texture.width), Float(texture.height), 1)
        }
    }
    
    override func draw(_ view: MTKView, _ commandBuffer: MTLCommandBuffer) {
        if updateParticles.value, spriteMesh.visible, linesMesh.pointsBuffer != nil {
            computeSystem.update(commandBuffer)
        }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        videoMaterial.texture = videoTexture
        renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
    }
    
    override func resize(_ size: (width: Float, height: Float)) {
        camera.aspect = size.width / size.height
        renderer.resize(size)
    }
    
    func updated(material: Material) {
        print("Material Updated: \(material.label)")
        _updateInspector = true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == "e" {
            openEditor()
        }
        else if event.characters == "i" {
            toggleInspector()
        }
        else if event.characters == "f" {
            fullscreen.value.toggle()
        }
    }
}
