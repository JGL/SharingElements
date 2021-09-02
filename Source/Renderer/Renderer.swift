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
class PostMaterial: LiveMaterial {}

class Renderer: Forge.Renderer, MaterialDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Elements

    var bodyComposition: Elements?
    
    // MARK: - Particles
    
    var metalFileCompiler = MetalFileCompiler()

    var particleCountValue: Int {
        switch particleCount.value {
        case "256 x 256":
            return 65536
        case "512 x 512":
            return 262144
        case "1024 x 1024":
            return 1048576
        default:
            return 65536
        }
    }
    
    lazy var particleCount: StringParameter = {
        let param = StringParameter("Particle Count", "256 x 256", ["256 x 256", "512 x 512", "1024 x 1024"], .dropdown) { [unowned self] _ in
            self.spriteMesh.instanceCount = self.particleCountValue
            self.computeSystem.count = self.particleCountValue
        }
        return param
    }()
    
    lazy var computeSystem: BufferComputeSystem = {
        let compute = BufferComputeSystem(context: context, count: particleCountValue, feedback: false)
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
    
    var mouseHidden: Bool = false {
        didSet {
            if mouseHidden {
                NSCursor.hide()
            }
            else
            {
                NSCursor.unhide()
            }
        }
    }
    
    lazy var spriteMaterial: SpriteMaterial = {
        let material = SpriteMaterial(pipelinesURL: pipelinesURL)
        material.delegate = self
        material.blending = .additive
        material.depthWriteEnabled = false
        return material
    }()
    
    lazy var spriteMesh: Mesh = {
        let mesh = Mesh(geometry: PointGeometry(), material: spriteMaterial)
        mesh.instanceCount = particleCountValue
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
    
    var presetsURL: URL {
        return getDocumentsAssetsDirectoryUrl("Presets")
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
            "Particles",
            "Post Processing"
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
            "Particles": computeParams,
            "Post Processing": postMaterial.parameters
        ]
    }
    
    var inspectorWindow: InspectorWindow?
    var _updateInspector: Bool = true
    var observers: [NSKeyValueObservation] = []
    
    // MARK: - Parameters
    
    var bgColor = Float4Parameter("Background", [1, 1, 1, 1], .colorpicker)
    var fullscreen = BoolParameter("Fullscreen", false, .toggle)
    var updatePose = BoolParameter("Update Pose", true, .toggle)
    lazy var cameraOffset: Float2Parameter = {
        let param = Float2Parameter("Camera Offset", [0, 0], .inputfield) { [unowned self] value in
            camera.position = simd_make_float3(-value.x, -value.y, 1000.0)
        }
        return param
    }()
    
    var hipExtension = FloatParameter("Hip Extension", 0.0, 0.0, 500.0, .slider)
    
    var fakePose = BoolParameter("Fake Pose", false, .toggle)
    
    var fakeLines: [simd_float3] = [
        simd_make_float3(-191.417542, 43.109070, 0.000000),
        simd_make_float3(-90.650269, 40.662903, 0.000000),
        simd_make_float3(-90.650269, 40.662903, 0.000000),
        simd_make_float3(18.745117, 34.053711, 0.000000),
        simd_make_float3(18.745117, 34.053711, 0.000000),
        simd_make_float3(77.517578, 33.638794, 0.000000),
        simd_make_float3(18.745117, 34.053711, 0.000000),
        simd_make_float3(46.117737, -163.745056, 0.000000),
        simd_make_float3(46.117737, -163.745056, 0.000000),
        simd_make_float3(-57.649292, -278.170410, 0.000000),
        simd_make_float3(-57.649292, -278.170410, 0.000000),
        simd_make_float3(-167.979126, -347.207123, 0.000000),
        simd_make_float3(46.117737, -163.745056, 0.000000),
        simd_make_float3(75.280396, -164.072021, 0.000000),
        simd_make_float3(77.517578, 33.638794, 0.000000),
        simd_make_float3(99.477173, 86.022461, 0.000000),
        simd_make_float3(77.517578, 33.638794, 0.000000),
        simd_make_float3(136.290039, 33.223816, 0.000000),
        simd_make_float3(136.290039, 33.223816, 0.000000),
        simd_make_float3(247.299805, 76.679321, 0.000000),
        simd_make_float3(247.299805, 76.679321, 0.000000),
        simd_make_float3(344.167847, 103.910950, 0.000000),
        simd_make_float3(136.290039, 33.223816, 0.000000),
        simd_make_float3(104.442993, -164.398956, 0.000000),
        simd_make_float3(104.442993, -164.398956, 0.000000),
        simd_make_float3(250.483887, -239.269867, 0.000000),
        simd_make_float3(250.483887, -239.269867, 0.000000),
        simd_make_float3(212.481323, -401.193481, 0.000000),
        simd_make_float3(104.442993, -164.398956, 0.000000),
        simd_make_float3(75.280396, -164.072021, 0.000000),
        simd_make_float3(77.517578, 33.638794, 0.000000),
        simd_make_float3(75.280396, -164.072021, 0.000000),
        simd_make_float3(18.745117, 34.053711, 0.000000),
        simd_make_float3(104.442993, -164.398956, 0.000000),
        simd_make_float3(136.290039, 33.223816, 0.000000),
        simd_make_float3(46.117737, -163.745056, 0.000000),
        simd_make_float3(128.328278, -16.181877, 0.000000),
        simd_make_float3(25.588272, -15.395981, 0.000000),
        simd_make_float3(120.366516, -65.587570, 0.000000),
        simd_make_float3(32.431427, -64.845673, 0.000000),
        simd_make_float3(112.404755, -114.993256, 0.000000),
        simd_make_float3(39.274582, -114.295364, 0.000000)
    ]
    
    var fakePoints: [simd_float3] = [
        simd_make_float3(77.517578, 33.638794, 0.000000),
        simd_make_float3(136.290039, 33.223816, 0.000000),
        simd_make_float3(-191.417542, 43.109070, 0.000000),
        simd_make_float3(18.745117, 34.053711, 0.000000),
        simd_make_float3(46.117737, -163.745056, 0.000000),
        simd_make_float3(111.938110, 87.548462, 0.000000),
        simd_make_float3(-90.650269, 40.662903, 0.000000),
        simd_make_float3(-167.979126, -347.207123, 0.000000),
        simd_make_float3(-57.649292, -278.170410, 0.000000),
        simd_make_float3(344.167847, 103.910950, 0.000000),
        simd_make_float3(247.299805, 76.679321, 0.000000),
        simd_make_float3(99.477173, 86.022461, 0.000000),
        simd_make_float3(89.326782, 103.510254, 0.000000),
        simd_make_float3(104.442993, -164.398956, 0.000000),
        simd_make_float3(212.481323, -401.193481, 0.000000),
        simd_make_float3(49.777588, 94.136780, 0.000000),
        simd_make_float3(110.225952, 102.882874, 0.000000),
        simd_make_float3(75.280396, -164.072021, 0.000000),
        simd_make_float3(250.483887, -239.269867, 0.000000)
    ]

    lazy var updateParticles: BoolParameter = {
        BoolParameter("Update Particles", true, .toggle)
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
    
    var postProcess = BoolParameter("Post Process", false, .toggle)
    
    lazy var blendModes: StringParameter = {
        var param = StringParameter("Blending", "Subtract", ["Additive", "Alpha", "Subtract"], .dropdown) { [unowned self] value in
            switch value {
            case "Additive":
                spriteMaterial.blending = .additive
            case "Alpha":
                spriteMaterial.blending = .alpha
            case "Subtract":
                spriteMaterial.blending = .subtract
            default:
                break
            }
        }
        return param
    }()
    
    lazy var appParams: ParameterGroup = {
        let params = ParameterGroup("Controls")
        params.append(bgColor)
        params.append(postProcess)
        params.append(blendModes)
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
        params.append(cameraOffset)
        params.append(hipExtension)
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
    
    lazy var spriteContainer: Object = {
        let container = Object()
        container.label = "Sprite Container"
        container.add(spriteMesh)
        return container
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
        scene.add(spriteContainer)
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
    
    var deltaTime: CFTimeInterval = 0.0
    
    var renderTextureSize = simd_int2(repeating: 0)
    var renderTexture: MTLTexture?
    lazy var postMaterial: PostMaterial = {
        let mat = PostMaterial(pipelinesURL: pipelinesURL)
        mat.delegate = self
        mat.blending = .disabled
        return mat
    }()
    
    lazy var postProcessor: PostProcessor = {
        let ppc = Context(device, sampleCount, colorPixelFormat, .invalid, .invalid)
        let pp = PostProcessor(context: ppc, material: postMaterial)
        pp.renderer.colorLoadAction = .clear
        pp.renderer.colorStoreAction = .store
        pp.renderer.setClearColor([0, 0, 0, 1])
        pp.label = "Post Processor"
        pp.mesh.preDraw = { [unowned self] renderEncoder in
            renderEncoder.setFragmentTexture(self.renderTexture, index: FragmentTextureIndex.Custom0.rawValue)
        }
        return pp
    }()
    
    override func setupMtkView(_ metalKitView: MTKView) {
        metalKitView.sampleCount = 1
        metalKitView.colorPixelFormat = .bgra8Unorm
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.preferredFramesPerSecond = 60
    }
    
    override init() {
        // do stuff here
    }
    
    func setupData() {
        let decoder = JSONDecoder()
        var data: Data
        do {
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
                massParams.append(FloatParameter(element.name.titleCase + " Mass", element.mass / 100.0, .inputfield))
            }
            self.colorParams = colorParams
            massesParams = massParams
            
            colorUniforms = UniformBuffer(context: context, parameters: colorParams)
            massUniforms = UniformBuffer(context: context, parameters: massParams)
        }
        catch {
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
        mouseHidden = true
    }
    
    public func cleanup() {
        print("Renderer Cleanup")
        save()
        stopCamera()
    }
    
    deinit {
        print("Renderer Deinit")
        cleanup()
    }
    
    func getTime() -> CFTimeInterval {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func updateTime() {
        currentTime = getTime()
        deltaTime = currentTime - lastTime
        lastTime = currentTime
    }

    func updateFullscreen() {
        if let window = mtkView.window {
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
    
    func updateRenderTexture() {
        if renderTextureSize.x != Int(mtkView.drawableSize.width) || renderTextureSize.y != Int(mtkView.drawableSize.height) {
            renderTexture = createTexture("Render Texture", Int(mtkView.drawableSize.width), Int(mtkView.drawableSize.height), colorPixelFormat, context.device)
            renderTextureSize = simd_make_int2(Int32(Int(mtkView.drawableSize.width)), Int32(mtkView.drawableSize.height))
        }
    }
    
    override func update() {
        updateFullscreen()
        updateTime()
        cameraController.update()
        updateBufferComputeUniforms()
        updateInspector()
        updateRenderTexture()
        
        videoMaterial.texture = videoTexture
        
        postMaterial.set("Time", Float(currentTime))
        postMaterial.set("Resolution", simd_make_float2(Float(mtkView.drawableSize.width), Float(mtkView.drawableSize.height)))
        
        if let texture = videoTexture, videoMesh.scale.x != Float(texture.width), videoMesh.scale.y != Float(texture.height) {
            videoMesh.scale = simd_make_float3((flipVideo.value ? -1.0 : 1.0) * Float(texture.width), Float(texture.height), 1)
        }
    }
    
    override func draw(_ view: MTKView, _ commandBuffer: MTLCommandBuffer) {
        if updateParticles.value, spriteMesh.visible, linesMesh.pointsBuffer != nil {
            computeSystem.update(commandBuffer)
            spriteContainer.visible = true
        }
        else {
            spriteContainer.visible = false
        }
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        if postProcess.value, let renderTexture = self.renderTexture {
            renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer, renderTarget: renderTexture)
            postProcessor.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
        }
        else {
            renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
        }
    }
    
    override func resize(_ size: (width: Float, height: Float)) {
        camera.aspect = size.width / size.height
        renderer.resize(size)
        postProcessor.resize(size)
    }
    
    func updated(material: Material) {
        print("Material Updated: \(material.label)")
        _updateInspector = true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == "e" {
            openEditor()
        }
        else if event.characters == "f" {
            fullscreen.value.toggle()
        }
        else if event.characters == "m" {
            mouseHidden = !mouseHidden 
        }
    }
    
    func createTexture(_ label: String, _ width: Int, _ height: Int, _ pixelFormat: MTLPixelFormat, _ device: MTLDevice) -> MTLTexture? {
        guard width > 0, height > 0 else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.sampleCount = 1
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        descriptor.resourceOptions = .storageModePrivate
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.label = label
        return texture
    }
}
