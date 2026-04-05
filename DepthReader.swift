import ARKit

/// Safely reads depth and confidence values from ARKit CVPixelBuffers
class DepthReader {
    
    // Exponential moving average state
    private var smoothedDistance: Float = 0
    private let smoothingAlpha: Float = 0.3
    private var hasInitialValue = false
    
    /// Read depth value at center of frame (for distance indicator)
    func readCenterDepth(from frame: ARFrame) -> Float? {
        guard let sceneDepth = frame.smoothedSceneDepth else { return nil }
        let depthMap = sceneDepth.depthMap
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        let centerX = width / 2
        let centerY = height / 2
        
        guard let rawDepth = readDepthValue(from: depthMap, x: centerX, y: centerY) else {
            return nil
        }
        
        // Apply exponential moving average for smoothing
        if !hasInitialValue {
            smoothedDistance = rawDepth
            hasInitialValue = true
        } else {
            smoothedDistance = smoothingAlpha * rawDepth + (1.0 - smoothingAlpha) * smoothedDistance
        }
        
        return smoothedDistance
    }
    
    /// Read a single depth value at (x, y) from CVPixelBuffer
    func readDepthValue(from pixelBuffer: CVPixelBuffer, x: Int, y: Int) -> Float? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pointer = baseAddress.advanced(by: y * bytesPerRow + x * MemoryLayout<Float>.size)
        let depth = pointer.assumingMemoryBound(to: Float.self).pointee
        
        // Filter invalid readings
        guard depth > 0, depth < 10.0, !depth.isNaN, !depth.isInfinite else { return nil }
        
        return depth
    }
    
    /// Extract full depth map as [Float] array
    func extractDepthArray(from pixelBuffer: CVPixelBuffer) -> [Float] {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let count = width * height
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Array(repeating: 0, count: count)
        }
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: floatBuffer, count: count))
    }
    
    /// Extract confidence map as [UInt8] array
    func extractConfidenceArray(from pixelBuffer: CVPixelBuffer) -> [UInt8] {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let count = width * height
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return Array(repeating: 0, count: count)
        }
        
        let uint8Buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: uint8Buffer, count: count))
    }
    
    /// Reset smoothing state
    func reset() {
        smoothedDistance = 0
        hasInitialValue = false
    }
}
