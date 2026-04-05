import simd
import CoreGraphics

/// Computes wound length, width, and perimeter from 3D contour points
class DimensionCalculator {
    
    struct DimensionResult {
        let lengthCm: Float
        let widthCm: Float
        let perimeterCm: Float
        let lengthLineStart: CGPoint  // In depth-map pixel coordinates
        let lengthLineEnd: CGPoint
        let widthLineStart: CGPoint
        let widthLineEnd: CGPoint
    }
    
    /// Compute dimensions from wound boundary points
    func compute(
        contourPoints3D: [SIMD3<Float>],
        contourPixelCoords: [(Int, Int)]
    ) -> DimensionResult {
        guard contourPoints3D.count >= 2 else {
            return DimensionResult(
                lengthCm: 0, widthCm: 0, perimeterCm: 0,
                lengthLineStart: .zero, lengthLineEnd: .zero,
                widthLineStart: .zero, widthLineEnd: .zero
            )
        }
        
        // Length: max 3D distance between any two contour points (rotating calipers simplified)
        var maxDist: Float = 0
        var lengthIdxA = 0, lengthIdxB = 0
        
        // Sample for performance if contour is very large
        let sampleStep = max(1, contourPoints3D.count / 200)
        let sampledIndices = stride(from: 0, to: contourPoints3D.count, by: sampleStep).map { $0 }
        
        for i in 0..<sampledIndices.count {
            for j in (i+1)..<sampledIndices.count {
                let dist = simd_distance(
                    contourPoints3D[sampledIndices[i]],
                    contourPoints3D[sampledIndices[j]]
                )
                if dist > maxDist {
                    maxDist = dist
                    lengthIdxA = sampledIndices[i]
                    lengthIdxB = sampledIndices[j]
                }
            }
        }
        
        let lengthM = maxDist
        
        // Width: max perpendicular span to the length axis
        let lengthAxis = simd_normalize(contourPoints3D[lengthIdxB] - contourPoints3D[lengthIdxA])
        let lengthOrigin = contourPoints3D[lengthIdxA]
        
        var maxPerpDist: Float = 0
        var widthIdxA = 0, widthIdxB = 0
        
        // Project all contour points onto perpendicular plane
        var perpDistances: [(index: Int, perpDist: Float)] = []
        for (i, point) in contourPoints3D.enumerated() {
            let diff = point - lengthOrigin
            let projLength = simd_dot(diff, lengthAxis)
            let projPoint = lengthOrigin + projLength * lengthAxis
            let perpVector = point - projPoint
            let perpDist = simd_length(perpVector)
            
            // Use signed perpendicular distance for width calculation
            let sign: Float = simd_dot(perpVector, SIMD3<Float>(0, 1, 0)) >= 0 ? 1 : -1
            perpDistances.append((index: i, perpDist: perpDist * sign))
        }
        
        // Width = max perpDist - min perpDist
        if let maxPerp = perpDistances.max(by: { $0.perpDist < $1.perpDist }),
           let minPerp = perpDistances.min(by: { $0.perpDist < $1.perpDist }) {
            maxPerpDist = maxPerp.perpDist - minPerp.perpDist
            widthIdxA = minPerp.index
            widthIdxB = maxPerp.index
        }
        
        let widthM = maxPerpDist
        
        // Perimeter: sum of consecutive 3D contour point distances
        var perimeterM: Float = 0
        for i in 0..<contourPoints3D.count {
            let next = (i + 1) % contourPoints3D.count
            perimeterM += simd_distance(contourPoints3D[i], contourPoints3D[next])
        }
        
        // Convert pixel coords to CGPoints for visualization
        let startA = contourPixelCoords.indices.contains(lengthIdxA) ? contourPixelCoords[lengthIdxA] : (0, 0)
        let endA = contourPixelCoords.indices.contains(lengthIdxB) ? contourPixelCoords[lengthIdxB] : (0, 0)
        let startW = contourPixelCoords.indices.contains(widthIdxA) ? contourPixelCoords[widthIdxA] : (0, 0)
        let endW = contourPixelCoords.indices.contains(widthIdxB) ? contourPixelCoords[widthIdxB] : (0, 0)
        
        return DimensionResult(
            lengthCm: lengthM * 100.0,
            widthCm: widthM * 100.0,
            perimeterCm: perimeterM * 100.0,
            lengthLineStart: CGPoint(x: startA.0, y: startA.1),
            lengthLineEnd: CGPoint(x: endA.0, y: endA.1),
            widthLineStart: CGPoint(x: startW.0, y: startW.1),
            widthLineEnd: CGPoint(x: endW.0, y: endW.1)
        )
    }
}
