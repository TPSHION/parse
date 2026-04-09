import Foundation
import AVFoundation

enum NativeAudioConversionError: LocalizedError {
    case noAudioTrack
    case exportSessionUnavailable
    case unsupportedOutputType
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return AppLocalizer.localized("未检测到可导出的音频轨道")
        case .exportSessionUnavailable:
            return AppLocalizer.localized("系统原生导出器不可用")
        case .unsupportedOutputType:
            return AppLocalizer.localized("当前文件不支持系统原生导出为 M4A")
        case .exportFailed(let message):
            return AppLocalizer.formatted("系统原生导出失败：%@", message)
        }
    }
}

struct NativeAudioConversionService {
    func exportToM4A(
        inputURL: URL,
        outputURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: inputURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NativeAudioConversionError.noAudioTrack
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NativeAudioConversionError.exportSessionUnavailable
        }
        
        guard exportSession.supportedFileTypes.contains(.m4a) else {
            throw NativeAudioConversionError.unsupportedOutputType
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        let progressTask = Task {
            while !Task.isCancelled {
                progressHandler(min(max(Double(exportSession.progress), 0.0), 0.95))
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        
        defer { progressTask.cancel() }
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            progressHandler(1.0)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw NativeAudioConversionError.exportFailed(error.localizedDescription)
        }
    }
}
