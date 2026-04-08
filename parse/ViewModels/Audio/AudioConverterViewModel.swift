import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class AudioConverterViewModel: ObservableObject {
    @Published var audioItems: [AudioItem] = []
    @Published var exportDocument: ConvertedAudioDocument?
    @Published var isImporting = false
    @Published var isConverting = false
    @Published var conversionMode: AudioConversionMode = .quality
    
    @Published var batchTargetFormat: AudioFormat = .mp3 {
        didSet {
            for index in audioItems.indices {
                if isReady(status: audioItems[index].status) {
                    audioItems[index].targetFormat = batchTargetFormat
                }
            }
        }
    }
    
    private let planner = AudioConversionPlanner()
    private let nativeService = NativeAudioConversionService()
    private let ffmpegService = FFmpegAudioConversionService()
    private var importActivityCount = 0
    
    var totalCount: Int { audioItems.count }
    var pendingCount: Int { audioItems.filter { $0.status == .pending }.count }
    var successCount: Int { audioItems.filter { $0.status == .success }.count }
    var convertingCount: Int { audioItems.filter { $0.status == .converting }.count }
    var failedCount: Int {
        audioItems.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }
    var readyCount: Int { audioItems.filter { isReady(status: $0.status) }.count }
    
    var conversionProgress: Double {
        guard totalCount > 0 else { return 0.0 }
        let totalProgress = audioItems.reduce(0.0) { partialResult, item in
            partialResult + overallProgress(for: item)
        }
        return totalProgress / Double(totalCount)
    }
    
    var canConvert: Bool {
        !audioItems.isEmpty && !isConverting && readyCount > 0
    }
    
    var canSave: Bool {
        hasSuccessItems && !isConverting && !isImporting
    }
    
    var hasSuccessItems: Bool {
        audioItems.contains { $0.status == .success }
    }
    
    var shareableURLs: [URL] {
        audioItems.compactMap { item in
            item.status == .success ? item.convertedURL : nil
        }
    }
    
    func prepareExportDocument() {
        let successItems = audioItems.filter { $0.status == .success }
        exportDocument = successItems.isEmpty ? nil : ConvertedAudioDocument(items: successItems)
    }
    
    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            beginImport()
            
            let targetFormat = batchTargetFormat
            Task.detached(priority: .userInitiated) { [urls, targetFormat] in
                let importedFiles = Self.importAudioFiles(from: urls)
                
                await MainActor.run {
                    self.audioItems.append(contentsOf: importedFiles.map {
                        AudioItem(url: $0.url, originalFilename: $0.originalFilename, targetFormat: targetFormat)
                    })
                    self.endImport()
                }
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    func updateTargetFormat(for id: UUID, to format: AudioFormat) {
        if let index = audioItems.firstIndex(where: { $0.id == id }) {
            if let oldURL = audioItems[index].convertedURL {
                try? FileManager.default.removeItem(at: oldURL)
            }
            audioItems[index].targetFormat = format
            audioItems[index].status = .pending
            audioItems[index].convertedURL = nil
            audioItems[index].conversionProgress = 0.0
        }
    }
    
    func removeItem(id: UUID) {
        guard let index = audioItems.firstIndex(where: { $0.id == id }) else { return }
        
        if let convertedURL = audioItems[index].convertedURL {
            try? FileManager.default.removeItem(at: convertedURL)
        }
        try? FileManager.default.removeItem(at: audioItems[index].url)
        audioItems.remove(at: index)
    }
    
    func clearAll() {
        for item in audioItems {
            if let convertedURL = item.convertedURL {
                try? FileManager.default.removeItem(at: convertedURL)
            }
            try? FileManager.default.removeItem(at: item.url)
        }
        audioItems.removeAll()
    }
    
    func startConversion() async {
        guard canConvert else { return }
        
        isConverting = true
        defer { isConverting = false }
        
        let targetIndexes = audioItems.indices.filter { isReady(status: audioItems[$0].status) }
        for index in targetIndexes {
            await convertItem(at: index)
        }
    }
    
    private func convertItem(at index: Int) async {
        guard audioItems.indices.contains(index) else { return }
        
        let item = audioItems[index]
        audioItems[index].status = .converting
        audioItems[index].conversionProgress = 0.0
        
        let outputURL = makeOutputURL(for: item)
        let plan = planner.makePlan(for: item, mode: conversionMode)
        
        do {
            switch plan.engine {
            case .directCopy:
                try copyFileDirectly(from: item.url, to: outputURL)
                audioItems[index].conversionProgress = 1.0
            case .nativeM4AExport:
                try await nativeService.exportToM4A(inputURL: item.url, outputURL: outputURL) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.applyProgress(progress, for: item.id)
                    }
                }
            case .ffmpegRemux:
                try await ffmpegService.remux(
                    inputURL: item.url,
                    outputURL: outputURL,
                    sourceFormat: item.originalFormat,
                    targetFormat: item.targetFormat
                )
                audioItems[index].conversionProgress = 1.0
            case .ffmpegTranscode:
                let duration = await audioDuration(for: item.url)
                try await ffmpegService.transcode(
                    inputURL: item.url,
                    outputURL: outputURL,
                    targetFormat: item.targetFormat,
                    mode: conversionMode,
                    duration: duration
                ) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.applyProgress(progress, for: item.id)
                    }
                }
            }
            
            guard let latestIndex = audioItems.firstIndex(where: { $0.id == item.id }) else { return }
            audioItems[latestIndex].convertedURL = outputURL
            audioItems[latestIndex].status = .success
            audioItems[latestIndex].conversionProgress = 1.0
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            guard let latestIndex = audioItems.firstIndex(where: { $0.id == item.id }) else { return }
            audioItems[latestIndex].status = .failed(error.localizedDescription)
            audioItems[latestIndex].convertedURL = nil
            audioItems[latestIndex].conversionProgress = 0.0
        }
    }
    
    private func applyProgress(_ progress: Double, for itemID: UUID) {
        guard let index = audioItems.firstIndex(where: { $0.id == itemID }) else { return }
        let currentProgress = audioItems[index].conversionProgress
        audioItems[index].conversionProgress = min(max(progress, currentProgress), 0.99)
    }
    
    private func makeOutputURL(for item: AudioItem) -> URL {
        let fileName = "\(item.baseName)_\(UUID().uuidString.prefix(6)).\(item.targetFormat.fileExtension)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    private func copyFileDirectly(from inputURL: URL, to outputURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.copyItem(at: inputURL, to: outputURL)
    }
    
    private func audioDuration(for url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds.isFinite ? max(duration.seconds, 0) : 0
        } catch {
            return 0
        }
    }
    
    private func overallProgress(for item: AudioItem) -> Double {
        switch item.status {
        case .pending:
            return 0.0
        case .converting:
            return item.conversionProgress
        case .success, .failed:
            return 1.0
        }
    }
    
    private func isReady(status: AudioItem.ConversionStatus) -> Bool {
        switch status {
        case .pending, .failed:
            return true
        case .converting, .success:
            return false
        }
    }
    
    private func beginImport() {
        importActivityCount += 1
        isImporting = importActivityCount > 0
    }
    
    private func endImport() {
        importActivityCount = max(0, importActivityCount - 1)
        isImporting = importActivityCount > 0
    }
    
    private struct ImportedAudioFile {
        let url: URL
        let originalFilename: String
    }
    
    private nonisolated static func importAudioFiles(from urls: [URL]) -> [ImportedAudioFile] {
        urls.compactMap { importAudioFile(from: $0) }
    }
    
    private nonisolated static func importAudioFile(from url: URL) -> ImportedAudioFile? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            return ImportedAudioFile(url: tempURL, originalFilename: url.lastPathComponent)
        } catch {
            print("Failed to copy imported audio file: \(error.localizedDescription)")
            return nil
        }
    }
}
