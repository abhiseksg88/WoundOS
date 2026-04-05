import XCTest
@testable import WoundOS

// MARK: - PUSH Calculator Tests
class PUSHCalculatorTests: XCTestCase {
    
    func testZeroArea() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0), 0)
    }
    
    func testSmallArea() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0.1), 1)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0.29), 1)
    }
    
    func testMediumArea() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0.5), 2)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0.8), 3)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 1.5), 4)
    }
    
    func testLargeArea() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 2.5), 5)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 3.5), 6)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 6.0), 7)
    }
    
    func testVeryLargeArea() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 10.0), 8)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 20.0), 9)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 30.0), 10)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 100.0), 10)
    }
    
    func testBoundaryValues() {
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 0.3), 2)
        XCTAssertEqual(PUSHCalculator.areaSubscale(areaCm2: 24.0), 10)
    }
}

// MARK: - Plane Fitter Tests
class PlaneFitterTests: XCTestCase {
    let fitter = PlaneFitter()
    
    func testFlatPlane() {
        // Points on z = 0.3 plane
        var points: [SIMD3<Float>] = []
        for x in stride(from: -0.05, to: 0.05, by: 0.01) {
            for y in stride(from: -0.05, to: 0.05, by: 0.01) {
                points.append(SIMD3<Float>(Float(x), Float(y), 0.3))
            }
        }
        
        let plane = fitter.fitPlane(to: points)
        XCTAssertNotNil(plane)
        
        // Normal should be approximately (0, 0, 1) or (0, 0, -1)
        if let p = plane {
            let nz = abs(p.normal.z)
            XCTAssertGreaterThan(nz, 0.95, "Normal Z component should be close to 1 for flat plane")
        }
    }
    
    func testInsufficientPoints() {
        let points: [SIMD3<Float>] = [SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0)]
        let plane = fitter.fitPlane(to: points)
        XCTAssertNil(plane, "Should return nil with < 3 points")
    }
    
    func testNoisyPlane() {
        var points: [SIMD3<Float>] = []
        for x in stride(from: -0.05, to: 0.05, by: 0.005) {
            for y in stride(from: -0.05, to: 0.05, by: 0.005) {
                let noise = Float.random(in: -0.001...0.001)
                points.append(SIMD3<Float>(Float(x), Float(y), 0.25 + noise))
            }
        }
        
        let plane = fitter.fitPlane(to: points)
        XCTAssertNotNil(plane)
        
        if let p = plane {
            // All points should be within 3mm of the plane
            for point in points {
                let dist = abs(p.signedDistance(to: point))
                XCTAssertLessThan(dist, 0.003, "Point should be within 3mm of fitted plane")
            }
        }
    }
}

// MARK: - Mask Processor Tests
class MaskProcessorTests: XCTestCase {
    
    func testConnectedComponentsSingle() {
        // 5x5 grid with single component
        let binary: [UInt8] = [
            0, 0, 0, 0, 0,
            0, 1, 1, 0, 0,
            0, 1, 1, 1, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 0, 0
        ]
        
        let labels = MaskProcessor.connectedComponents(binary: binary, width: 5, height: 5)
        let maxLabel = labels.max() ?? 0
        XCTAssertEqual(maxLabel, 1, "Should detect 1 connected component")
    }
    
    func testConnectedComponentsMultiple() {
        // 5x5 grid with two separate components
        let binary: [UInt8] = [
            1, 1, 0, 0, 0,
            1, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 1, 1,
            0, 0, 0, 1, 1
        ]
        
        let labels = MaskProcessor.connectedComponents(binary: binary, width: 5, height: 5)
        let maxLabel = labels.max() ?? 0
        XCTAssertEqual(maxLabel, 2, "Should detect 2 connected components")
    }
    
    func testDilate() {
        let binary: [UInt8] = [
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0
        ]
        
        let dilated = MaskProcessor.dilate(binary: binary, width: 5, height: 5, radius: 1)
        
        // Center and immediate neighbors should be 1
        XCTAssertEqual(dilated[2 * 5 + 2], 1) // Center
        XCTAssertEqual(dilated[1 * 5 + 2], 1) // Above
        XCTAssertEqual(dilated[3 * 5 + 2], 1) // Below
        XCTAssertEqual(dilated[2 * 5 + 1], 1) // Left
        XCTAssertEqual(dilated[2 * 5 + 3], 1) // Right
        
        // Corners should still be 0
        XCTAssertEqual(dilated[0], 0) // Top-left
        XCTAssertEqual(dilated[4], 0) // Top-right
    }
}

// MARK: - Surface Area Tests
class SurfaceAreaTests: XCTestCase {
    
    func testPixelAreaEstimate() {
        // At 25cm distance with typical depth intrinsics
        let area = SurfaceAreaCalculator.estimateAreaFromPixels(
            pixelCount: 1000,
            captureDistanceM: 0.25,
            depthWidth: 256,
            depthHeight: 192,
            intrinsics: CaptureData.CameraIntrinsics(fx: 200, fy: 200, cx: 128, cy: 96)
        )
        
        // Each pixel at 25cm: (0.25/200)^2 = 1.5625e-6 m²
        // 1000 pixels * 1.5625e-6 * 10000 = 15.625 cm²
        XCTAssertGreaterThan(area, 0, "Area should be positive")
        XCTAssertLessThan(area, 100, "Area should be reasonable")
    }
}

// MARK: - Measurement Confidence Tests
class MeasurementConfidenceTests: XCTestCase {
    
    func testHighConfidence() {
        let conf = MeasurementConfidence.assess(
            depthCoverage: 0.9,
            captureDistanceCm: 25,
            pointCount: 1000
        )
        XCTAssertEqual(conf, .high)
    }
    
    func testLowConfidence() {
        let conf = MeasurementConfidence.assess(
            depthCoverage: 0.2,
            captureDistanceCm: 60,
            pointCount: 50
        )
        XCTAssertEqual(conf, .low)
    }
}
