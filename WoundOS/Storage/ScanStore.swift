import UIKit

/// Local persistence for wound scans
class ScanStore: ObservableObject {
    static let shared = ScanStore()
    
    @Published var records: [ScanRecord] = []
    
    private let fileManager = FileManager.default
    private var scansDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Scans", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var indexURL: URL {
        scansDirectory.appendingPathComponent("index.json")
    }
    
    init() {
        loadIndex()
    }
    
    // MARK: - Save
    func save(
        measurement: WoundMeasurement,
        captureImage: UIImage,
        overlayImage: UIImage?,
        maskImage: UIImage
    ) async {
        let id = UUID().uuidString
        let scanDir = scansDirectory.appendingPathComponent(id, isDirectory: true)
        try? fileManager.createDirectory(at: scanDir, withIntermediateDirectories: true)
        
        // Save images
        let captureURL = scanDir.appendingPathComponent("capture.jpg")
        try? captureImage.jpegData(compressionQuality: 0.85)?.write(to: captureURL)
        
        let overlayURL = scanDir.appendingPathComponent("overlay.jpg")
        try? overlayImage?.jpegData(compressionQuality: 0.85)?.write(to: overlayURL)
        
        let maskURL = scanDir.appendingPathComponent("mask.png")
        try? maskImage.pngData()?.write(to: maskURL)
        
        // Save measurement JSON
        let measurementURL = scanDir.appendingPathComponent("measurement.json")
        try? JSONEncoder().encode(measurement).write(to: measurementURL)
        
        // Create record
        let record = ScanRecord(
            id: id,
            timestamp: measurement.timestamp,
            areaCm2: measurement.totalAreaCm2,
            numRegions: measurement.numRegions,
            captureImagePath: "capture.jpg",
            overlayImagePath: "overlay.jpg",
            confidence: measurement.confidence
        )
        
        await MainActor.run {
            records.insert(record, at: 0)
            saveIndex()
        }
    }
    
    // MARK: - Load
    func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.timestamp > $1.timestamp }
    }
    
    func loadMeasurement(for record: ScanRecord) -> WoundMeasurement? {
        let url = scansDirectory.appendingPathComponent(record.id).appendingPathComponent("measurement.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WoundMeasurement.self, from: data)
    }
    
    func loadCaptureImage(for record: ScanRecord) -> UIImage? {
        let url = scansDirectory.appendingPathComponent(record.id).appendingPathComponent(record.captureImagePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func loadOverlayImage(for record: ScanRecord) -> UIImage? {
        guard let path = record.overlayImagePath else { return nil }
        let url = scansDirectory.appendingPathComponent(record.id).appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Delete
    func delete(record: ScanRecord) {
        let scanDir = scansDirectory.appendingPathComponent(record.id)
        try? fileManager.removeItem(at: scanDir)
        records.removeAll { $0.id == record.id }
        saveIndex()
    }
    
    // MARK: - Private
    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: indexURL)
    }
}

/// Codable record for a saved scan
struct ScanRecord: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let areaCm2: Float
    let numRegions: Int
    let captureImagePath: String
    let overlayImagePath: String?
    let confidence: MeasurementConfidence
}
