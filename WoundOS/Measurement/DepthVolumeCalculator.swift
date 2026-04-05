import simd

/// Computes wound depth and volume relative to the reference plane
class DepthVolumeCalculator {
    
    struct DepthVolumeResult {
        let maxDepthMm: Float
        let meanDepthMm: Float
        let volumeMl: Float
        let deepestPointIndex: Int
    }
    
    /// Compute depth statistics and volume from wound points relative to reference plane
    func compute(
        woundPoints: [SIMD3<Float>],
        plane: PlaneFitter.Plane,
        pixelCoords: [(Int, Int)],
        depthWidth: Int,
        intrinsics: CaptureData.CameraIntrinsics,
        captureDistanceM: Float
    ) -> DepthVolumeResult {
        guard !woundPoints.isEmpty else {
            return DepthVolumeResult(maxDepthMm: 0, meanDepthMm: 0, volumeMl: 0, deepestPointIndex: 0)
        }
        
        var maxDepth: Float = 0
        var sumDepth: Float = 0
        var sumVolume: Float = 0
        var deepestIdx = 0
        var validCount = 0
        
        // Pixel area at capture distance (approximate)
        let pixelSizeX = captureDistanceM / intrinsics.fx
        let pixelSizeY = captureDistanceM / intrinsics.fy
        let pixelAreaM2 = pixelSizeX * pixelSizeY
        
        for (i, point) in woundPoints.enumerated() {
            // Signed distance to plane: positive = below surface (cavity)
            let signedDist = plane.signedDistance(to: point)
            
            // Only consider points below the skin surface
            let depth = max(0, signedDist)
            
            if depth > 0 {
                validCount += 1
                sumDepth += depth
                sumVolume += depth * pixelAreaM2
                
                if depth > maxDepth {
                    maxDepth = depth
                    deepestIdx = i
                }
            }
        }
        
        let meanDepth = validCount > 0 ? sumDepth / Float(validCount) : 0
        
        return DepthVolumeResult(
            maxDepthMm: maxDepth * 1000.0,       // m → mm
            meanDepthMm: meanDepth * 1000.0,      // m → mm
            volumeMl: sumVolume * 1_000_000.0,    // m³ → mL (cm³)
            deepestPointIndex: deepestIdx
        )
    }
}
