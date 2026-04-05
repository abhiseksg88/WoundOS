import Foundation
import simd

/// Orchestrates all measurement steps: point cloud → plane → area → depth → dimensions
class MeasurementPipeline {
    
    private let pointCloudBuilder = PointCloudBuilder()
    private let planeFitter = PlaneFitter()
    private let areaCalculator = SurfaceAreaCalculator()
    private let depthVolumeCalculator = DepthVolumeCalculator()
    private let dimensionCalculator = DimensionCalculator()
    
    /// Run the full measurement pipeline
    func measure(
        captureData: CaptureData,
        segmentation: SegmentationResult
    ) async -> WoundMeasurement {
        
        // Step 0: Resize mask to depth resolution
        guard let resizedMask = MaskProcessor.resizeMask(
            segmentation.mask,
            toWidth: captureData.depthWidth,
            toHeight: captureData.depthHeight
        ),
        let (binaryMask, maskWidth, maskHeight) = MaskProcessor.toBinaryArray(resizedMask) else {
            return emptyMeasurement(captureData: captureData)
        }
        
        // Scale intrinsics from RGB to depth resolution
        let scaledIntrinsics = captureData.intrinsics.scaled(
            toWidth: captureData.depthWidth,
            toHeight: captureData.depthHeight,
            fromWidth: captureData.rgbWidth,
            fromHeight: captureData.rgbHeight
        )
        
        // Run connected components for multi-wound support
        let labels = MaskProcessor.connectedComponents(
            binary: binaryMask,
            width: maskWidth,
            height: maskHeight
        )
        let maxLabel = labels.max() ?? 0
        
        if maxLabel == 0 {
            return emptyMeasurement(captureData: captureData)
        }
        
        // Process each wound region
        var regions: [RegionMeasurement] = []
        
        for regionId in 1...maxLabel {
            // Create per-region mask
            let regionMask = labels.map { UInt8($0 == regionId ? 1 : 0) }
            let pixelCount = regionMask.reduce(0) { $0 + Int($1) }
            guard pixelCount > 50 else { continue } // Skip tiny noise regions
            
            let regionResult = measureRegion(
                id: regionId,
                mask: regionMask,
                depth: captureData.depthMap,
                confidence: captureData.confidenceMap,
                width: maskWidth,
                height: maskHeight,
                intrinsics: scaledIntrinsics,
                captureDistanceM: captureData.captureDistance
            )
            regions.append(regionResult)
        }
        
        // Sort by area (largest first)
        regions.sort { $0.areaCm2 > $1.areaCm2 }
        
        let totalArea = regions.reduce(0) { $0 + $1.areaCm2 }
        let totalVolume = regions.reduce(0) { $0 + $1.volumeMl }
        let totalPoints = regions.reduce(0) { _ , r in
            Int(r.areaCm2 * 100) // Rough proxy
        }
        
        let confidence = MeasurementConfidence.assess(
            depthCoverage: 0.8, // Will be refined per-region
            captureDistanceCm: captureData.captureDistance * 100,
            pointCount: totalPoints
        )
        
        return WoundMeasurement(
            regions: regions,
            totalAreaCm2: totalArea,
            totalVolumeMl: totalVolume,
            numRegions: regions.count,
            measurementMode: "3d_lidar",
            validDepthCoverage: 0.8,
            captureDistanceCm: captureData.captureDistance * 100,
            confidence: confidence,
            timestamp: captureData.timestamp
        )
    }
    
    // MARK: - Per-Region Measurement
    private func measureRegion(
        id: Int,
        mask: [UInt8],
        depth: [Float],
        confidence: [UInt8],
        width: Int,
        height: Int,
        intrinsics: CaptureData.CameraIntrinsics,
        captureDistanceM: Float
    ) -> RegionMeasurement {
        
        // Step 1: Build point clouds
        let pcResult = pointCloudBuilder.buildPointCloud(
            mask: mask,
            depth: depth,
            confidence: confidence,
            width: width,
            height: height,
            intrinsics: intrinsics
        )
        
        guard pcResult.woundPoints.count >= 3 else {
            return fallbackRegionMeasurement(
                id: id,
                pixelCount: mask.reduce(0) { $0 + Int($1) },
                captureDistanceM: captureDistanceM,
                width: width,
                height: height,
                intrinsics: intrinsics
            )
        }
        
        // Step 2: Fit reference plane from periwound
        let plane: PlaneFitter.Plane
        if pcResult.periwoundPoints.count >= 10 {
            plane = planeFitter.fitPlane(to: pcResult.periwoundPoints) ??
                    planeFitter.fitPlane(to: pcResult.woundPoints) ??
                    PlaneFitter.Plane(normal: SIMD3<Float>(0, 0, 1), d: -captureDistanceM)
        } else {
            // Fallback: use wound points themselves or a z-plane
            plane = planeFitter.fitPlane(to: pcResult.woundPoints) ??
                    PlaneFitter.Plane(normal: SIMD3<Float>(0, 0, 1), d: -captureDistanceM)
        }
        
        // Step 3: Compute area
        var areaCm2 = areaCalculator.computeArea(
            woundPoints: pcResult.woundPoints,
            plane: plane,
            depthWidth: width,
            depthHeight: height,
            pixelCoords: pcResult.woundPixelCoords
        )
        
        // Fallback if triangulation gives zero
        if areaCm2 < 0.01 {
            areaCm2 = SurfaceAreaCalculator.estimateAreaFromPixels(
                pixelCount: pcResult.woundPoints.count,
                captureDistanceM: captureDistanceM,
                depthWidth: width,
                depthHeight: height,
                intrinsics: intrinsics
            )
        }
        
        // Step 4: Compute depth and volume
        let depthVolume = depthVolumeCalculator.compute(
            woundPoints: pcResult.woundPoints,
            plane: plane,
            pixelCoords: pcResult.woundPixelCoords,
            depthWidth: width,
            intrinsics: intrinsics,
            captureDistanceM: captureDistanceM
        )
        
        // Step 5: Compute dimensions (from contour edge points)
        let contourPoints = extractContourPoints3D(
            from: mask, points: pcResult.woundPoints,
            pixelCoords: pcResult.woundPixelCoords,
            width: width, height: height
        )
        
        let dimensions = dimensionCalculator.compute(
            contourPoints3D: contourPoints.points,
            contourPixelCoords: contourPoints.coords
        )
        
        // Deepest point coordinate
        let deepestCoord: CGPoint
        if depthVolume.deepestPointIndex < pcResult.woundPixelCoords.count {
            let (dx, dy) = pcResult.woundPixelCoords[depthVolume.deepestPointIndex]
            deepestCoord = CGPoint(x: dx, y: dy)
        } else {
            deepestCoord = .zero
        }
        
        // Centroid
        let centroidX = pcResult.woundPixelCoords.reduce(0) { $0 + $1.0 } / max(1, pcResult.woundPixelCoords.count)
        let centroidY = pcResult.woundPixelCoords.reduce(0) { $0 + $1.1 } / max(1, pcResult.woundPixelCoords.count)
        
        return RegionMeasurement(
            id: id,
            areaCm2: areaCm2,
            maxLengthCm: dimensions.lengthCm,
            maxWidthCm: dimensions.widthCm,
            maxDepthMm: depthVolume.maxDepthMm,
            meanDepthMm: depthVolume.meanDepthMm,
            volumeMl: depthVolume.volumeMl,
            perimeterCm: dimensions.perimeterCm,
            centroid: CodableCGPoint(x: CGFloat(centroidX), y: CGFloat(centroidY)),
            lengthLineStart: CodableCGPoint(dimensions.lengthLineStart),
            lengthLineEnd: CodableCGPoint(dimensions.lengthLineEnd),
            widthLineStart: CodableCGPoint(dimensions.widthLineStart),
            widthLineEnd: CodableCGPoint(dimensions.widthLineEnd),
            deepestPoint: CodableCGPoint(deepestCoord)
        )
    }
    
    // MARK: - Contour Extraction in 3D
    private func extractContourPoints3D(
        from mask: [UInt8],
        points: [SIMD3<Float>],
        pixelCoords: [(Int, Int)],
        width: Int,
        height: Int
    ) -> (points: [SIMD3<Float>], coords: [(Int, Int)]) {
        // Build lookup
        var coordToIdx = [Int: Int]()
        for (i, c) in pixelCoords.enumerated() {
            coordToIdx[c.1 * width + c.0] = i
        }
        
        var contourPts: [SIMD3<Float>] = []
        var contourCoords: [(Int, Int)] = []
        
        for (i, c) in pixelCoords.enumerated() {
            let (x, y) = c
            let isEdge = x == 0 || x == width-1 || y == 0 || y == height-1 ||
                mask[(y-1)*width+x] == 0 ||
                mask[(y+1)*width+x] == 0 ||
                mask[y*width+(x-1)] == 0 ||
                mask[y*width+(x+1)] == 0
            
            if isEdge {
                contourPts.append(points[i])
                contourCoords.append(c)
            }
        }
        
        // Sort by angle from centroid
        if !contourPts.isEmpty {
            let cx = contourCoords.reduce(0.0) { $0 + Float($1.0) } / Float(contourCoords.count)
            let cy = contourCoords.reduce(0.0) { $0 + Float($1.1) } / Float(contourCoords.count)
            
            var indexed = Array(zip(contourPts.indices, contourCoords))
            indexed.sort { a, b in
                let angleA = atan2(Float(a.1.1) - cy, Float(a.1.0) - cx)
                let angleB = atan2(Float(b.1.1) - cy, Float(b.1.0) - cx)
                return angleA < angleB
            }
            
            contourPts = indexed.map { contourPts[$0.0] }
            contourCoords = indexed.map { $0.1 }
        }
        
        return (contourPts, contourCoords)
    }
    
    // MARK: - Fallbacks
    private func emptyMeasurement(captureData: CaptureData) -> WoundMeasurement {
        WoundMeasurement(
            regions: [],
            totalAreaCm2: 0,
            totalVolumeMl: 0,
            numRegions: 0,
            measurementMode: "3d_lidar",
            validDepthCoverage: 0,
            captureDistanceCm: captureData.captureDistance * 100,
            confidence: .low,
            timestamp: captureData.timestamp
        )
    }
    
    private func fallbackRegionMeasurement(
        id: Int,
        pixelCount: Int,
        captureDistanceM: Float,
        width: Int,
        height: Int,
        intrinsics: CaptureData.CameraIntrinsics
    ) -> RegionMeasurement {
        let area = SurfaceAreaCalculator.estimateAreaFromPixels(
            pixelCount: pixelCount,
            captureDistanceM: captureDistanceM,
            depthWidth: width,
            depthHeight: height,
            intrinsics: intrinsics
        )
        
        return RegionMeasurement(
            id: id, areaCm2: area,
            maxLengthCm: 0, maxWidthCm: 0,
            maxDepthMm: 0, meanDepthMm: 0,
            volumeMl: 0, perimeterCm: 0,
            centroid: CodableCGPoint(x: 0, y: 0),
            lengthLineStart: CodableCGPoint(x: 0, y: 0),
            lengthLineEnd: CodableCGPoint(x: 0, y: 0),
            widthLineStart: CodableCGPoint(x: 0, y: 0),
            widthLineEnd: CodableCGPoint(x: 0, y: 0),
            deepestPoint: CodableCGPoint(x: 0, y: 0)
        )
    }
}
