import SwiftUI

struct ResultsScreen: View {
    @EnvironmentObject var flow: CaptureFlowCoordinator
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var show3DView = false
    
    private var measurement: WoundMeasurement? { flow.measurement }
    private var primary: RegionMeasurement? { measurement?.primary }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Section A: Hero Image
                    heroImage
                    
                    // Section B: Primary Measurement Card
                    primaryMeasurementCard
                    
                    // Section C: Multi-Wound Breakdown
                    if let m = measurement, m.numRegions > 1 {
                        multiWoundBreakdown
                    }
                    
                    // Section D: Depth Heatmap
                    depthMapCard
                    
                    // Section E: PUSH Score
                    pushScoreCard
                    
                    // Section F: Clinical Summary
                    clinicalSummaryCard
                    
                    // Bottom padding for action bar
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.Colors.groupedBackground)
            
            // Sticky bottom action bar
            actionBar
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    // Save scan and exit
                    saveScan()
                    flow.exitCaptureFlow()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
        }
        .fullScreenCover(isPresented: $show3DView) {
            if let m = measurement, let capture = flow.captureData, let seg = flow.segmentationResult {
                DepthScene3DView(measurement: m, captureData: capture, segmentation: seg)
            }
        }
    }
    
    // MARK: - Section A: Hero Image
    private var heroImage: some View {
        Group {
            if let captureData = flow.captureData, let m = measurement {
                let annotatedImage = AnnotatedImageRenderer.render(
                    original: flow.segmentationResult?.overlay ?? captureData.rgbImage,
                    measurement: m,
                    imageWidth: captureData.rgbWidth,
                    imageHeight: captureData.rgbHeight,
                    depthWidth: captureData.depthWidth,
                    depthHeight: captureData.depthHeight
                )
                
                Image(uiImage: annotatedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(Theme.CornerRadius.card)
                    .cardShadow()
            }
        }
    }
    
    // MARK: - Section B: Primary Measurement Card
    private var primaryMeasurementCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Title
                Text("Wound Area")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.secondaryLabel)
                
                // Hero number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", primary?.areaCm2 ?? 0))
                        .font(Theme.Typography.heroMeasurement)
                        .foregroundColor(Theme.Colors.primaryLabel)
                    
                    Text("cm²")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryLabel)
                }
                
                Divider()
                
                // Sub-metrics grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: Theme.Spacing.md) {
                    MeasurementCard(
                        title: "Length",
                        value: String(format: "%.1f", primary?.maxLengthCm ?? 0),
                        unit: "cm"
                    )
                    MeasurementCard(
                        title: "Width",
                        value: String(format: "%.1f", primary?.maxWidthCm ?? 0),
                        unit: "cm"
                    )
                    MeasurementCard(
                        title: "Max Depth",
                        value: String(format: "%.1f", primary?.maxDepthMm ?? 0),
                        unit: "mm"
                    )
                    MeasurementCard(
                        title: "Volume",
                        value: String(format: "%.1f", primary?.volumeMl ?? 0),
                        unit: "mL"
                    )
                }
                
                // Perimeter
                MeasurementCard(
                    title: "Perimeter",
                    value: String(format: "%.1f", primary?.perimeterCm ?? 0),
                    unit: "cm"
                )
                
                // Footer
                Divider()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Measured via LiDAR · ±5% accuracy")
                        .font(Theme.Typography.footer)
                        .foregroundColor(Theme.Colors.tertiaryLabel)
                    Text("Captured at \(Int(measurement?.captureDistanceCm ?? 0)) cm distance")
                        .font(Theme.Typography.footer)
                        .foregroundColor(Theme.Colors.tertiaryLabel)
                }
            }
        }
    }
    
    // MARK: - Section C: Multi-Wound Breakdown
    private var multiWoundBreakdown: some View {
        SectionCard {
            DisclosureGroup {
                VStack(spacing: Theme.Spacing.sm) {
                    if let regions = measurement?.regions {
                        ForEach(Array(regions.enumerated()), id: \.offset) { index, region in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Region \(index + 1)\(index == 0 ? " (largest)" : "")")
                                    .font(.subheadline.weight(.medium))
                                
                                HStack {
                                    Text("Area: \(String(format: "%.1f", region.areaCm2)) cm²")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text("Depth: \(String(format: "%.1f", region.maxDepthMm)) mm")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if index < regions.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } label: {
                Text("\(measurement?.numRegions ?? 0) Wound Regions")
                    .font(Theme.Typography.sectionHeader)
            }
        }
    }
    
    // MARK: - Section D: Depth Map
    private var depthMapCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Wound Depth Map")
                        .font(Theme.Typography.sectionHeader)
                    
                    Spacer()
                    
                    Button {
                        show3DView = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View 3D")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "cube")
                        }
                        .foregroundColor(Theme.Colors.interactive)
                    }
                }
                
                // Heatmap image
                if let capture = flow.captureData, let seg = flow.segmentationResult {
                    let heatmap = DepthHeatmapRenderer.render(
                        depth: capture.depthMap,
                        mask: seg.mask,
                        width: capture.depthWidth,
                        height: capture.depthHeight
                    )
                    Image(uiImage: heatmap)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                    
                    // Legend
                    HStack(spacing: 16) {
                        legendItem(color: .green, text: "< 2mm")
                        legendItem(color: .yellow, text: "2-5mm")
                        legendItem(color: .red, text: "> 5mm")
                    }
                    .font(.caption)
                }
                
                if let p = primary {
                    Text("Mean depth: \(String(format: "%.1f", p.meanDepthMm)) mm")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.secondaryLabel)
                }
            }
        }
    }
    
    // MARK: - Section E: PUSH Score
    private var pushScoreCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("PUSH Score (Area Component)")
                    .font(Theme.Typography.sectionHeader)
                
                let score = PUSHCalculator.areaSubscale(areaCm2: primary?.areaCm2 ?? 0)
                
                HStack(alignment: .firstTextBaseline) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold))
                    Text("/ 10")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(pushColor(score: score))
                            .frame(width: geo.size.width * CGFloat(score) / 10.0, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text("Based on wound area of \(String(format: "%.2f", primary?.areaCm2 ?? 0)) cm²")
                    .font(Theme.Typography.footer)
                    .foregroundColor(Theme.Colors.tertiaryLabel)
                
                Text("Full PUSH score requires clinical input for exudate and tissue type.")
                    .font(Theme.Typography.footer)
                    .foregroundColor(Theme.Colors.tertiaryLabel)
            }
        }
    }
    
    // MARK: - Section F: Clinical Summary
    private var clinicalSummaryCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Measurement Summary")
                    .font(Theme.Typography.sectionHeader)
                
                if let m = measurement, let p = primary {
                    Text(ClinicalSummaryGenerator.generate(measurement: m, region: p))
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.secondaryLabel)
                        .lineSpacing(4)
                }
            }
        }
    }
    
    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                generateAndSharePDF()
            } label: {
                Label("Share Report", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                saveScan()
                flow.retake()
            } label: {
                Label("New Scan", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helpers
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
    
    private func pushColor(score: Int) -> Color {
        if score <= 3 { return .green }
        if score <= 6 { return .orange }
        return .red
    }
    
    private func saveScan() {
        guard let m = measurement,
              let capture = flow.captureData,
              let seg = flow.segmentationResult else { return }
        
        Task {
            await ScanStore.shared.save(
                measurement: m,
                captureImage: capture.rgbImage,
                overlayImage: seg.overlay,
                maskImage: seg.mask
            )
        }
    }
    
    private func generateAndSharePDF() {
        guard let m = measurement,
              let capture = flow.captureData,
              let seg = flow.segmentationResult else { return }
        
        let data = PDFReportGenerator.generate(
            measurement: m,
            captureImage: capture.rgbImage,
            overlayImage: seg.overlay ?? capture.rgbImage,
            depthMap: capture.depthMap,
            mask: seg.mask,
            depthWidth: capture.depthWidth,
            depthHeight: capture.depthHeight
        )
        self.pdfData = data
        self.showShareSheet = true
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
