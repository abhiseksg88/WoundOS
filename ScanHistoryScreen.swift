import SwiftUI

struct ScanHistoryScreen: View {
    @StateObject private var store = ScanStore.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    emptyState
                } else {
                    scanList
                }
            }
            .navigationTitle("Scan History")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Scans Yet")
                .font(.title3.weight(.medium))
            Text("Capture your first wound measurement to see it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var scanList: some View {
        List {
            ForEach(store.records) { record in
                NavigationLink {
                    ScanDetailView(record: record)
                } label: {
                    scanRow(record)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    store.delete(record: store.records[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func scanRow(_ record: ScanRecord) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let image = store.loadOverlayImage(for: record) ?? store.loadCaptureImage(for: record) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.2f cm²", record.areaCm2))
                    .font(.headline)
                
                if record.numRegions > 1 {
                    Text("\(record.numRegions) regions")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Text(record.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Confidence badge
            Text(record.confidence.rawValue.capitalized)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(confidenceColor(record.confidence).opacity(0.15))
                .foregroundColor(confidenceColor(record.confidence))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private func confidenceColor(_ confidence: MeasurementConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

// MARK: - Scan Detail View
struct ScanDetailView: View {
    let record: ScanRecord
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = ScanStore.shared.loadOverlayImage(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                }
                
                if let measurement = ScanStore.shared.loadMeasurement(for: record),
                   let primary = measurement.primary {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wound Area")
                                .font(Theme.Typography.label)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f cm²", primary.areaCm2))
                                .font(Theme.Typography.heroMeasurement)
                            
                            Divider()
                            
                            Group {
                                infoRow("Length", "\(String(format: "%.1f", primary.maxLengthCm)) cm")
                                infoRow("Width", "\(String(format: "%.1f", primary.maxWidthCm)) cm")
                                infoRow("Max Depth", "\(String(format: "%.1f", primary.maxDepthMm)) mm")
                                infoRow("Volume", "\(String(format: "%.1f", primary.volumeMl)) mL")
                                infoRow("Perimeter", "\(String(format: "%.1f", primary.perimeterCm)) cm")
                            }
                            
                            Divider()
                            
                            let push = PUSHCalculator.areaSubscale(areaCm2: primary.areaCm2)
                            infoRow("PUSH Area Score", "\(push)/10")
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.groupedBackground)
        .navigationTitle("Scan Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
