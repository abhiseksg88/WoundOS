import simd

/// RANSAC-based plane fitting for the periwound reference surface
class PlaneFitter {
    
    struct Plane {
        let normal: SIMD3<Float>
        let d: Float  // ax + by + cz + d = 0
        
        /// Signed distance from point to plane (positive = below plane / cavity)
        func signedDistance(to point: SIMD3<Float>) -> Float {
            return simd_dot(normal, point) + d
        }
    }
    
    /// Fit a plane to periwound points using RANSAC
    /// - Parameters:
    ///   - points: 3D periwound points
    ///   - iterations: Number of RANSAC iterations (default 100)
    ///   - inlierThreshold: Distance threshold in meters (default 2mm = 0.002m)
    /// - Returns: Best-fit plane, or nil if insufficient points
    func fitPlane(
        to points: [SIMD3<Float>],
        iterations: Int = 100,
        inlierThreshold: Float = 0.002
    ) -> Plane? {
        guard points.count >= 3 else { return nil }
        
        var bestPlane: Plane?
        var bestInlierCount = 0
        
        for _ in 0..<iterations {
            // Sample 3 random points
            let indices = randomSample(count: 3, from: points.count)
            let p0 = points[indices[0]]
            let p1 = points[indices[1]]
            let p2 = points[indices[2]]
            
            // Compute plane from 3 points via cross product
            let v1 = p1 - p0
            let v2 = p2 - p0
            var normal = simd_cross(v1, v2)
            
            let length = simd_length(normal)
            guard length > 1e-8 else { continue }  // Degenerate (collinear points)
            normal = normal / length  // Normalize
            
            let d = -simd_dot(normal, p0)
            let candidatePlane = Plane(normal: normal, d: d)
            
            // Count inliers
            var inlierCount = 0
            for point in points {
                let dist = abs(candidatePlane.signedDistance(to: point))
                if dist < inlierThreshold {
                    inlierCount += 1
                }
            }
            
            if inlierCount > bestInlierCount {
                bestInlierCount = inlierCount
                bestPlane = candidatePlane
            }
        }
        
        // Refine: refit plane using all inliers of the best model
        if let best = bestPlane {
            let inliers = points.filter { abs(best.signedDistance(to: $0)) < inlierThreshold }
            if inliers.count >= 3 {
                if let refined = fitPlaneLeastSquares(inliers) {
                    return refined
                }
            }
        }
        
        return bestPlane
    }
    
    /// Least-squares plane fit (for refinement after RANSAC)
    private func fitPlaneLeastSquares(_ points: [SIMD3<Float>]) -> Plane? {
        guard points.count >= 3 else { return nil }
        
        // Compute centroid
        var centroid = SIMD3<Float>(0, 0, 0)
        for p in points { centroid += p }
        centroid /= Float(points.count)
        
        // Build covariance matrix
        var xx: Float = 0, xy: Float = 0, xz: Float = 0
        var yy: Float = 0, yz: Float = 0, zz: Float = 0
        
        for p in points {
            let r = p - centroid
            xx += r.x * r.x
            xy += r.x * r.y
            xz += r.x * r.z
            yy += r.y * r.y
            yz += r.y * r.z
            zz += r.z * r.z
        }
        
        // Determinants for normal vector (smallest eigenvector via cofactors)
        let detX = yy * zz - yz * yz
        let detY = xx * zz - xz * xz
        let detZ = xx * yy - xy * xy
        
        var normal: SIMD3<Float>
        if detX >= detY && detX >= detZ {
            normal = SIMD3<Float>(detX, xz * yz - xy * zz, xy * yz - xz * yy)
        } else if detY >= detX && detY >= detZ {
            normal = SIMD3<Float>(xz * yz - xy * zz, detY, xy * xz - yz * xx)
        } else {
            normal = SIMD3<Float>(xy * yz - xz * yy, xy * xz - yz * xx, detZ)
        }
        
        let length = simd_length(normal)
        guard length > 1e-8 else { return nil }
        normal = normal / length
        
        let d = -simd_dot(normal, centroid)
        return Plane(normal: normal, d: d)
    }
    
    /// Generate random sample indices without replacement
    private func randomSample(count: Int, from total: Int) -> [Int] {
        var indices = Set<Int>()
        while indices.count < count {
            indices.insert(Int.random(in: 0..<total))
        }
        return Array(indices)
    }
}
