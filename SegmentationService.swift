import UIKit

/// Handles wound segmentation via mock data or real API
class SegmentationService {
    static let shared = SegmentationService()
    
    /// Toggle between mock and real API
    var useMockAPI: Bool {
        get { UserDefaults.standard.bool(forKey: "useMockAPI") == false ? true : UserDefaults.standard.bool(forKey: "useMockAPI") }
        set { UserDefaults.standard.set(newValue, forKey: "useMockAPI") }
    }
    
    var apiEndpoint: String {
        get { UserDefaults.standard.string(forKey: "apiEndpoint") ?? "https://wound-ai-api-333499614175.us-central1.run.app" }
        set { UserDefaults.standard.set(newValue, forKey: "apiEndpoint") }
    }
    
    private init() {
        // Default to mock API on first launch
        if UserDefaults.standard.object(forKey: "useMockAPI") == nil {
            UserDefaults.standard.set(true, forKey: "useMockAPI")
        }
    }
    
    /// Perform segmentation on captured image
    func segment(image: Data) async throws -> SegmentationResult {
        if useMockAPI {
            return try await mockSegment(image: image)
        } else {
            return try await apiSegment(image: image)
        }
    }
    
    // MARK: - Mock Segmentation
    private func mockSegment(image: Data) async throws -> SegmentationResult {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1.5))
        
        // Return bundled sample mask
        let sampleMasks = ["mask_patientA", "mask_patientB", "mask_patientC"]
        let maskName = sampleMasks.randomElement()!
        
        guard let maskImage = UIImage(named: maskName) ?? generateMockMask() else {
            throw SegmentationError.mockDataMissing
        }
        
        // Generate overlay from mask on the captured image
        let sourceImage = UIImage(data: image) ?? UIImage()
        let overlay = MaskProcessor.drawContourOverlay(on: sourceImage, mask: maskImage)
        let contours = MaskProcessor.extractContours(from: maskImage)
        let pixelCount = MaskProcessor.countWhitePixels(maskImage)
        
        return SegmentationResult(
            segmentationId: UUID().uuidString,
            mask: maskImage,
            overlay: overlay,
            contours: contours,
            woundPixels: pixelCount,
            confidence: Float.random(in: 0.82...0.95),
            model: "mock_sample_\(maskName)",
            inferenceMs: 1500
        )
    }
    
    /// Generate a synthetic elliptical mask if bundle masks are missing
    private func generateMockMask() -> UIImage? {
        let size = CGSize(width: 640, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // White elliptical "wound" region
            UIColor.white.setFill()
            let woundRect = CGRect(
                x: size.width * 0.3,
                y: size.height * 0.3,
                width: size.width * 0.4,
                height: size.height * 0.35
            )
            let path = UIBezierPath(ovalIn: woundRect)
            // Add some irregularity
            path.fill()
        }
    }
    
    // MARK: - Real API Segmentation
    private func apiSegment(image: Data) async throws -> SegmentationResult {
        let url = URL(string: apiEndpoint + "/segment")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        
        // Build multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"wound.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(image)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SegmentationError.invalidResponse
        }
        
        // Parse JSON response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SegmentationError.invalidResponse
        }
        
        // Decode mask from base64
        guard let maskB64 = json["mask_b64"] as? String,
              let maskData = Data(base64Encoded: maskB64),
              let maskImage = UIImage(data: maskData) else {
            throw SegmentationError.invalidResponse
        }
        
        // Decode overlay if present
        var overlayImage: UIImage? = nil
        if let overlayB64 = json["overlay_b64"] as? String,
           let overlayData = Data(base64Encoded: overlayB64) {
            overlayImage = UIImage(data: overlayData)
        }
        
        let contours = MaskProcessor.extractContours(from: maskImage)
        let pixelCount = MaskProcessor.countWhitePixels(maskImage)
        let confidence = (json["confidence"] as? NSNumber)?.floatValue ?? 0.85
        let model = json["model"] as? String ?? "woundambit"
        let inferenceMs = (json["inference_ms"] as? NSNumber)?.intValue ?? 0
        
        return SegmentationResult(
            segmentationId: json["segmentation_id"] as? String ?? UUID().uuidString,
            mask: maskImage,
            overlay: overlayImage,
            contours: contours,
            woundPixels: pixelCount,
            confidence: confidence,
            model: model,
            inferenceMs: inferenceMs
        )
    }
}
