import simd

/// Computes wound surface area via triangulation of 3D point cloud
class SurfaceAreaCalculator {
    
    /// Compute surface area of wound points projected and triangulated
    /// Uses simplified grid-based triangulation (avoids Delaunay dependency)
    func computeArea(
        woundPoints: [SIMD3<Float>],
        plane: PlaneFitter.Plane,
        depthWidth: Int,
        depthHeight: Int,
        pixelCoords: [(Int, Int)]
    ) -> Float {
        guard woundPoints.count >= 3 else { return 0 }
        
        // Strategy: Use pixel grid adjacency for triangulation
        // Build a lookup from pixel coordinate to 3D point index
        var coordToIndex = [Int: Int]()  // key = y * depthWidth + x
        for (i, coord) in pixelCoords.enumerated() {
            let key = coord.1 * depthWidth + coord.0
            coordToIndex[key] = i
        }
        
        var totalArea: Float = 0
        
        // For each pixel that's part of the wound, form triangles with right and bottom neighbors
        for (i, coord) in pixelCoords.enumerated() {
            let (x, y) = coord
            
            // Triangle 1: (x,y), (x+1,y), (x,y+1)
            let rightKey = y * depthWidth + (x + 1)
            let bottomKey = (y + 1) * depthWidth + x
            
            if let rightIdx = coordToIndex[rightKey],
               let bottomIdx = coordToIndex[bottomKey] {
                let area = triangleArea3D(
                    woundPoints[i],
                    woundPoints[rightIdx],
                    woundPoints[bottomIdx]
                )
                totalArea += area
            }
            
            // Triangle 2: (x+1,y), (x+1,y+1), (x,y+1)
            let diagKey = (y + 1) * depthWidth + (x + 1)
            if let rightIdx = coordToIndex[rightKey],
               let bottomIdx = coordToIndex[bottomKey],
               let diagIdx = coordToIndex[diagKey] {
                let area = triangleArea3D(
                    woundPoints[rightIdx],
                    woundPoints[diagIdx],
                    woundPoints[bottomIdx]
                )
                totalArea += area
            }
        }
        
        // Convert m² to cm²
        return totalArea * 10000.0
    }
    
    /// Compute area of a 3D triangle using cross product
    private func triangleArea3D(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
        let ab = b - a
        let ac = c - a
        let cross = simd_cross(ab, ac)
        return simd_length(cross) * 0.5
    }
    
    /// Fallback: estimate area from point count and pixel spacing
    /// Used when triangulation yields too few triangles
    static func estimateAreaFromPixels(
        pixelCount: Int,
        captureDistanceM: Float,
        depthWidth: Int,
        depthHeight: Int,
        intrinsics: CaptureData.CameraIntrinsics
    ) -> Float {
        // Average pixel size at capture distance
        let pixelSizeX = captureDistanceM / intrinsics.fx
        let pixelSizeY = captureDistanceM / intrinsics.fy
        let pixelAreaM2 = pixelSizeX * pixelSizeY
        
        return Float(pixelCount) * pixelAreaM2 * 10000.0  // cm²
    }
}
