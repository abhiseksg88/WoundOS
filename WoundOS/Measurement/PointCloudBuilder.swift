import simd

/// Builds 3D point clouds from mask + depth data using camera intrinsics
class PointCloudBuilder {
    
    struct PointCloudResult {
        let woundPoints: [SIMD3<Float>]
        let periwoundPoints: [SIMD3<Float>]
        let validDepthRatio: Float
        /// Mapping from wound point index to (u,v) pixel coordinate in depth map
        let woundPixelCoords: [(Int, Int)]
    }
    
    /// Backproject wound pixels to 3D using depth and camera intrinsics
    func buildPointCloud(
        mask: [UInt8],
        depth: [Float],
        confidence: [UInt8],
        width: Int,
        height: Int,
        intrinsics: CaptureData.CameraIntrinsics
    ) -> PointCloudResult {
        var woundPoints: [SIMD3<Float>] = []
        var woundPixelCoords: [(Int, Int)] = []
        var totalWoundPixels = 0
        var validWoundPixels = 0
        
        // Build wound point cloud
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                guard mask[idx] == 1 else { continue }
                totalWoundPixels += 1
                
                let d = depth[idx]
                // Filter: valid depth, within reasonable range, sufficient confidence
                guard d > 0, d < 1.5 else { continue }
                if !confidence.isEmpty && confidence[idx] < 1 { continue }
                
                // Backproject: pixel (u,v) + depth → 3D point
                let xWorld = (Float(x) - intrinsics.cx) * d / intrinsics.fx
                let yWorld = (Float(y) - intrinsics.cy) * d / intrinsics.fy
                let zWorld = d
                
                woundPoints.append(SIMD3<Float>(xWorld, yWorld, zWorld))
                woundPixelCoords.append((x, y))
                validWoundPixels += 1
            }
        }
        
        // Build periwound point cloud (dilated ring outside wound)
        let dilatedMask = MaskProcessor.dilate(binary: mask, width: width, height: height, radius: 15)
        var periwoundPoints: [SIMD3<Float>] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                // Periwound = dilated but NOT wound
                guard dilatedMask[idx] == 1 && mask[idx] == 0 else { continue }
                
                let d = depth[idx]
                guard d > 0, d < 1.5 else { continue }
                if !confidence.isEmpty && confidence[idx] < 1 { continue }
                
                let xWorld = (Float(x) - intrinsics.cx) * d / intrinsics.fx
                let yWorld = (Float(y) - intrinsics.cy) * d / intrinsics.fy
                let zWorld = d
                
                periwoundPoints.append(SIMD3<Float>(xWorld, yWorld, zWorld))
            }
        }
        
        let validRatio = totalWoundPixels > 0 ? Float(validWoundPixels) / Float(totalWoundPixels) : 0
        
        return PointCloudResult(
            woundPoints: woundPoints,
            periwoundPoints: periwoundPoints,
            validDepthRatio: validRatio,
            woundPixelCoords: woundPixelCoords
        )
    }
}
