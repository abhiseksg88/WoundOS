import SwiftUI
import SceneKit

/// 3D wound topography visualization using SceneKit
struct DepthScene3DView: View {
    let measurement: WoundMeasurement
    let captureData: CaptureData
    let segmentation: SegmentationResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            SceneKitView(
                depth: captureData.depthMap,
                mask: segmentation.mask,
                width: captureData.depthWidth,
                height: captureData.depthHeight
            )
            .ignoresSafeArea()
            .navigationTitle("3D Wound View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SceneKitView: UIViewRepresentable {
    let depth: [Float]
    let mask: UIImage
    let width: Int
    let height: Int
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = buildScene()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        scnView.autoenablesDefaultLighting = true
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        
        // Get binary mask
        guard let resized = MaskProcessor.resizeMask(mask, toWidth: width, toHeight: height),
              let (binary, _, _) = MaskProcessor.toBinaryArray(resized) else {
            return scene
        }
        
        // Find depth stats for wound region
        var sumD: Float = 0
        var countD = 0
        for i in 0..<min(depth.count, binary.count) {
            if binary[i] == 1 && depth[i] > 0 && depth[i] < 1.5 {
                sumD += depth[i]
                countD += 1
            }
        }
        let meanD = countD > 0 ? sumD / Float(countD) : 0.3
        
        // Build mesh vertices (subsample for performance)
        let step = 2
        var vertices: [SCNVector3] = []
        var colors: [SCNVector3] = []
        var indices: [Int32] = []
        var vertexMap = [Int: Int32]() // key -> vertex index
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let idx = y * width + x
                guard idx < binary.count, idx < depth.count else { continue }
                guard binary[idx] == 1 && depth[idx] > 0 else { continue }
                
                let relDepth = (depth[idx] - meanD) * 50  // Exaggerate for visibility
                let vx = Float(x - width/2) * 0.01
                let vy = Float(height/2 - y) * 0.01
                let vz = -relDepth
                
                let vertIdx = Int32(vertices.count)
                vertexMap[y * width + x] = vertIdx
                vertices.append(SCNVector3(vx, vy, vz))
                
                // Color by depth
                let depthMm = abs(depth[idx] - meanD) * 1000
                if depthMm < 2 {
                    colors.append(SCNVector3(0.2, 0.8, 0.3)) // Green
                } else if depthMm < 5 {
                    colors.append(SCNVector3(0.9, 0.7, 0.1)) // Yellow
                } else {
                    colors.append(SCNVector3(0.9, 0.2, 0.2)) // Red
                }
            }
        }
        
        // Build triangles
        for y in stride(from: 0, to: height - step, by: step) {
            for x in stride(from: 0, to: width - step, by: step) {
                let k00 = y * width + x
                let k10 = y * width + (x + step)
                let k01 = (y + step) * width + x
                let k11 = (y + step) * width + (x + step)
                
                if let v00 = vertexMap[k00], let v10 = vertexMap[k10], let v01 = vertexMap[k01] {
                    indices.append(contentsOf: [v00, v10, v01])
                }
                if let v10 = vertexMap[k10], let v11 = vertexMap[k11], let v01 = vertexMap[k01] {
                    indices.append(contentsOf: [v10, v11, v01])
                }
            }
        }
        
        guard !vertices.isEmpty, !indices.isEmpty else { return scene }
        
        // Create geometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let colorSource = SCNGeometrySource(
            data: Data(bytes: colors, count: colors.count * MemoryLayout<SCNVector3>.size),
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )
        
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.lightingModel = .lambert
        geometry.materials = [material]
        
        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)
        
        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 40
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(cameraNode)
        
        // Light
        let light = SCNLight()
        light.type = .directional
        light.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 2, 3)
        lightNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(lightNode)
        
        return scene
    }
}
