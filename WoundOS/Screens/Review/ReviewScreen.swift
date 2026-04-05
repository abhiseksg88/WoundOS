import SwiftUI

struct ReviewScreen: View {
    @EnvironmentObject var flow: CaptureFlowCoordinator
    @State private var imageScale: CGFloat = 1.0
    @State private var isProcessingMeasurement = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                // Wound overlay image (pinch-to-zoom)
                woundImageView
                
                Spacer()
                
                // Bottom info card
                bottomInfoCard
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                flow.retake()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Retake")
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            Text("Wound Boundary")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                confirmMeasurement()
            } label: {
                HStack(spacing: 4) {
                    Text("Confirm")
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(Theme.Colors.interactive)
                .fontWeight(.semibold)
            }
            .disabled(isProcessingMeasurement)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Wound Image
    private var woundImageView: some View {
        GeometryReader { geo in
            if let overlayImage = flow.segmentationResult?.overlay ?? flow.captureData?.rgbImage {
                Image(uiImage: overlayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .scaleEffect(imageScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                imageScale = max(1.0, min(scale, 4.0))
                            }
                            .onEnded { _ in
                                withAnimation {
                                    if imageScale < 1.2 { imageScale = 1.0 }
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Bottom Info Card
    private var bottomInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let seg = flow.segmentationResult {
                // Confidence bar
                HStack(spacing: 4) {
                    Text("AI Confidence:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    confidenceDots(seg.confidence)
                    
                    Text(confidenceLabel(seg.confidence))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(confidenceColor(seg.confidence))
                    
                    Text("(\(Int(seg.confidence * 100))%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Region count
                Text("Wound regions detected: \(seg.contours.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Pixel area
                if seg.contours.count > 1 {
                    Text("Total wound area: ~\(seg.woundPixels.formatted()) pixels")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let largest = seg.contours.first {
                        Text("Largest region: ~\(largest.area.formatted()) pixels")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Wound area: ~\(seg.woundPixels.formatted()) pixels")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Tap Confirm to compute 3D measurements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isProcessingMeasurement {
                ProgressView("Computing measurements...")
                    .font(.caption)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.CornerRadius.card)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helpers
    private func confidenceDots(_ confidence: Float) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(Float(i) / 5.0 < confidence ? confidenceColor(confidence) : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 { return Theme.Colors.healthy }
        if confidence >= 0.6 { return Theme.Colors.caution }
        return Theme.Colors.warning
    }
    
    private func confidenceLabel(_ confidence: Float) -> String {
        if confidence >= 0.8 { return "High" }
        if confidence >= 0.6 { return "Medium" }
        return "Low"
    }
    
    private func confirmMeasurement() {
        guard let captureData = flow.captureData,
              let segResult = flow.segmentationResult else { return }
        
        isProcessingMeasurement = true
        
        Task {
            let pipeline = MeasurementPipeline()
            let measurement = await pipeline.measure(
                captureData: captureData,
                segmentation: segResult
            )
            
            await MainActor.run {
                isProcessingMeasurement = false
                flow.onConfirmed(measurement: measurement)
            }
        }
    }
}
