import SwiftUI
import PhotosUI
import Combine
import ffmpegkit
import AVFoundation

struct MovieTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            // 为了安全起见，我们将收到的文件拷贝到临时目录
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieTransferable(url: copy)
        }
    }
}

@MainActor
class VideoConverterViewModel: ObservableObject {
    private static let stoppedMessage = "已停止转换"
    
    private enum ConversionAttemptResult {
        case success
        case failure(String)
    }
    
    private enum FFmpegProfile {
        case quality
        case speed
    }
    
    enum ConversionMode: String, CaseIterable, Identifiable {
        case quality = "质量优先"
        case speed = "速度优先"
        
        var id: String { self.rawValue }
    }
    
    @Published var videoItems: [VideoItem] = []
    @Published var exportDocument: ConvertedVideosDocument?
    
    @Published var conversionMode: ConversionMode = .quality
    
    @Published var maxConcurrentTasks: Int = 2
    
    @Published var batchTargetFormat: VideoFormat = .mp4 {
        didSet {
            for i in videoItems.indices {
                if videoItems[i].status == .pending || isFailed(status: videoItems[i].status) {
                    videoItems[i].targetFormat = batchTargetFormat
                }
            }
        }
    }
    
    @Published var isConverting: Bool = false
    @Published var isImporting: Bool = false
    
    private var shouldStopConversion = false
    private var activeNativeExportSessions: [UUID: AVAssetExportSession] = [:]
    
    // MARK: - 统计属性
    var totalCount: Int { videoItems.count }
    var successCount: Int { videoItems.filter { $0.status == .success }.count }
    var failedCount: Int { videoItems.filter { isFailed(status: $0.status) }.count }
    var pendingCount: Int { videoItems.filter { $0.status == .pending }.count }
    var convertingCount: Int { videoItems.filter { $0.status == .converting }.count }
    var readyCount: Int { videoItems.filter { $0.status == .pending || isFailed(status: $0.status) }.count }
    var totalDuration: Double { videoItems.reduce(0) { $0 + $1.duration } }
    var totalSizeInBytes: Int64 {
        videoItems.reduce(0) { partialResult, item in
            partialResult + (item.fileSizeInBytes ?? 0)
        }
    }
    
    var conversionProgress: Double {
        guard totalCount > 0 else { return 0.0 }
        let totalProgress = videoItems.reduce(0.0) { partialResult, item in
            partialResult + overallProgress(for: item)
        }
        return totalProgress / Double(totalCount)
    }
    
    var shareableURLs: [URL] {
        videoItems.compactMap { item in
            item.status == .success ? item.convertedFileURL : nil
        }
    }
    
    var hasSuccessItems: Bool {
        videoItems.contains { $0.status == .success }
    }
    
    var canConvert: Bool {
        !videoItems.isEmpty
    }
    
    var canSave: Bool {
        hasSuccessItems && !isConverting
    }
    
    // MARK: - 操作
    func addVideo(url: URL, name: String, format: String) async {
        let thumbnail = try? await generateThumbnail(from: url)
        let duration = await getVideoDuration(url: url)
        let fileSizeInBytes = videoFileSize(for: url)
        let newItem = VideoItem(
            originalURL: url,
            originalName: name,
            originalFormat: format,
            thumbnail: thumbnail,
            duration: duration,
            fileSizeInBytes: fileSizeInBytes,
            targetFormat: batchTargetFormat
        )
        videoItems.append(newItem)
    }
    
    func updateTargetFormat(for itemID: UUID, to format: VideoFormat) {
        guard let index = videoItems.firstIndex(where: { $0.id == itemID }) else { return }
        videoItems[index].targetFormat = format
        videoItems[index].status = .pending
        videoItems[index].conversionProgress = 0.0
        
        if let oldURL = videoItems[index].convertedFileURL {
            try? FileManager.default.removeItem(at: oldURL)
        }
        videoItems[index].convertedFileURL = nil
    }
    
    func removeItems(at offsets: IndexSet) {
        for index in offsets {
            if let url = videoItems[index].convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            // 清理拷贝到沙盒的原始临时文件
            try? FileManager.default.removeItem(at: videoItems[index].originalURL)
        }
        videoItems.remove(atOffsets: offsets)
    }
    
    func removeItem(id: UUID) {
        guard let index = videoItems.firstIndex(where: { $0.id == id }) else { return }
        removeItems(at: IndexSet(integer: index))
    }
    
    func clearAll() {
        for item in videoItems {
            if let url = item.convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            try? FileManager.default.removeItem(at: item.originalURL)
        }
        videoItems.removeAll()
    }
    
    func prepareExportDocument() {
        let successItems = videoItems.filter { $0.status == .success }
        exportDocument = successItems.isEmpty ? nil : ConvertedVideosDocument(items: successItems)
    }
    
    func handlePrimaryAction() async {
        if isConverting {
            stopConversions()
        } else {
            await convertAll()
        }
    }
    
    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { [weak self] in
                guard let self else { return }
                await self.importVideos(from: urls)
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    func processVideoSelections(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        isImporting = true
        
        Task {
            for selection in selections {
                do {
                    if let movie = try await selection.loadTransferable(type: MovieTransferable.self) {
                        let url = movie.url
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd_HHmmss"
                        let timeString = formatter.string(from: Date())
                        let randomSuffix = String(Int.random(in: 100...999))
                        let name = "VID_\(timeString)_\(randomSuffix)"
                        let format = url.pathExtension.uppercased()
                        
                        await self.addVideo(url: url, name: name, format: format.isEmpty ? "未知" : format)
                    } else {
                        print("Failed to load video URL.")
                    }
                } catch {
                    print("Error loading video: \(error.localizedDescription)")
                }
            }
            self.isImporting = false
        }
    }
    
    private func importVideos(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
            
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                let name = url.deletingPathExtension().lastPathComponent
                let format = url.pathExtension.uppercased()
                await addVideo(url: tempURL, name: name, format: format.isEmpty ? "未知" : format)
            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 转换逻辑 (FFmpeg)
    func convertAll() async {
        let pendingIndexes = videoItems.indices.filter { index in
            let item = videoItems[index]
            return item.status == .pending || isFailed(status: item.status)
        }
        
        guard !pendingIndexes.isEmpty else { return }
        
        shouldStopConversion = false
        isConverting = true
        defer {
            isConverting = false
            shouldStopConversion = false
            activeNativeExportSessions.removeAll()
        }
        
        let concurrencyLimit = min(max(maxConcurrentTasks, 1), pendingIndexes.count)
        
        await withTaskGroup(of: Void.self) { group in
            var nextOffset = 0
            
            func enqueueNextTaskIfNeeded() async {
                let shouldStop = await MainActor.run { self.shouldStopConversion }
                guard !shouldStop, nextOffset < pendingIndexes.count else { return }
                let index = pendingIndexes[nextOffset]
                nextOffset += 1
                group.addTask { [weak self] in
                    guard let self else { return }
                    await self.convertItem(at: index)
                }
            }
            
            for _ in 0..<concurrencyLimit {
                await enqueueNextTaskIfNeeded()
            }
            
            while await group.next() != nil {
                await enqueueNextTaskIfNeeded()
            }
        }
    }
    
    func stopConversions() {
        guard isConverting else { return }
        shouldStopConversion = true
        
        for session in activeNativeExportSessions.values {
            session.cancelExport()
        }
        
        FFmpegKit.cancel()
    }
    
    private func convertItem(at index: Int) async {
        guard videoItems.indices.contains(index), !shouldStopConversion else { return }
        
        let item = videoItems[index]
        videoItems[index].status = .converting
        videoItems[index].conversionProgress = 0.0
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let ext = item.targetFormat.fileExtension
        let fileName = "\(item.originalName)_\(UUID().uuidString.prefix(6)).\(ext)"
        let outputURL = tempDirectory.appendingPathComponent(fileName)
        
        let result: ConversionAttemptResult
        if conversionMode == .quality {
            result = await convertWithQualityPriority(item: item, outputURL: outputURL, index: index)
        } else {
            result = await convertWithSpeedPriority(item: item, outputURL: outputURL, index: index)
        }
        
        switch result {
        case .success:
            guard !shouldStopConversion else {
                try? FileManager.default.removeItem(at: outputURL)
                videoItems[index].status = .failed(Self.stoppedMessage)
                videoItems[index].conversionProgress = 0.0
                return
            }
            videoItems[index].convertedFileURL = outputURL
            videoItems[index].status = .success
            videoItems[index].conversionProgress = 1.0
        case .failure(let message):
            videoItems[index].status = .failed(message)
            try? FileManager.default.removeItem(at: outputURL)
        }
    }
    
    private func convertWithQualityPriority(item: VideoItem, outputURL: URL, index: Int) async -> ConversionAttemptResult {
        if shouldTryLosslessRemux(for: item) {
            let remuxResult = await remuxWithoutReencode(item: item, outputURL: outputURL)
            if case .success = remuxResult {
                return remuxResult
            }
        }
        
        if shouldTryNativeExport(for: item),
           let nativeResult = await exportUsingNativeSession(item: item, outputURL: outputURL, index: index) {
            if case .success = nativeResult {
                return nativeResult
            }
        }
        
        return await convertWithFFmpeg(
            item: item,
            outputURL: outputURL,
            index: index,
            profile: .quality,
            stageLabel: "质量优先兜底转码"
        )
    }
    
    private func convertWithSpeedPriority(item: VideoItem, outputURL: URL, index: Int) async -> ConversionAttemptResult {
        if shouldTryFastRemux(for: item) {
            let remuxResult = await remuxWithoutReencode(item: item, outputURL: outputURL)
            if case .success = remuxResult {
                return remuxResult
            }
        }
        
        return await convertWithFFmpeg(
            item: item,
            outputURL: outputURL,
            index: index,
            profile: .speed,
            stageLabel: "速度优先快速转码"
        )
    }
    
    private func shouldTryLosslessRemux(for item: VideoItem) -> Bool {
        switch (item.originalFormat.lowercased(), item.targetFormat) {
        case ("mov", .mp4), ("mp4", .mov), ("mov", .mov), ("mp4", .mp4):
            return true
        default:
            return false
        }
    }
    
    private func shouldTryNativeExport(for item: VideoItem) -> Bool {
        switch item.targetFormat {
        case .mp4, .mov:
            return true
        case .gif, .avi, .mkv:
            return false
        }
    }
    
    private func shouldTryFastRemux(for item: VideoItem) -> Bool {
        switch (item.originalFormat.lowercased(), item.targetFormat) {
        case ("mov", .mp4), ("mp4", .mp4), ("mov", .mov), ("mp4", .mov), ("mov", .mkv), ("mp4", .mkv):
            return true
        default:
            return false
        }
    }
    
    private func remuxWithoutReencode(item: VideoItem, outputURL: URL) async -> ConversionAttemptResult {
        let inputPath = item.originalURL.path
        let outputPath = outputURL.path
        let command = "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? -c copy -movflags +faststart -y \"\(outputPath)\""
        return await executeFFmpegCommand(command, outputURL: outputURL, stageLabel: "无损封装")
    }
    
    private func exportUsingNativeSession(item: VideoItem, outputURL: URL, index: Int) async -> ConversionAttemptResult? {
        let asset = AVURLAsset(url: item.originalURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return nil
        }
        
        let outputFileType: AVFileType
        switch item.targetFormat {
        case .mp4:
            outputFileType = .mp4
        case .mov:
            outputFileType = .mov
        case .gif, .avi, .mkv:
            return nil
        }
        
        guard exportSession.supportedFileTypes.contains(outputFileType) else {
            print("==== 系统原生导出跳过 ====")
            print("原因: 不支持输出类型 \(outputFileType.rawValue)")
            print("========================")
            return nil
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        let sessionID = UUID()
        activeNativeExportSessions[sessionID] = exportSession
        
        let progressTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let progress = Double(exportSession.progress)
                await MainActor.run {
                    let current = self.videoItems[index].conversionProgress
                    self.videoItems[index].conversionProgress = min(max(progress, current), 0.95)
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        
        defer {
            progressTask.cancel()
            activeNativeExportSessions.removeValue(forKey: sessionID)
        }
        
        do {
            try await exportSession.export(to: outputURL, as: outputFileType)
            if shouldStopConversion {
                try? FileManager.default.removeItem(at: outputURL)
                return .failure(Self.stoppedMessage)
            }
            return .success
        } catch {
            if shouldStopConversion {
                try? FileManager.default.removeItem(at: outputURL)
                return .failure(Self.stoppedMessage)
            }
            let message = error.localizedDescription
            print("==== 系统原生导出失败 ====")
            print("Error: \(message)")
            print("========================")
            try? FileManager.default.removeItem(at: outputURL)
            return .failure("系统原生导出失败：\(message)")
        }
    }
    
    private func convertWithFFmpeg(
        item: VideoItem,
        outputURL: URL,
        index: Int,
        profile: FFmpegProfile,
        stageLabel: String
    ) async -> ConversionAttemptResult {
        let command = buildFFmpegCommand(for: item, outputURL: outputURL, profile: profile)
        let duration = await getVideoDuration(url: item.originalURL)
        return await executeFFmpegCommand(command, outputURL: outputURL, stageLabel: stageLabel, duration: duration) { [weak self] progress in
            guard let self else { return }
            let safeProgress = min(max(progress, self.videoItems[index].conversionProgress), 0.99)
            self.videoItems[index].conversionProgress = safeProgress
        }
    }
    
    private func buildFFmpegCommand(for item: VideoItem, outputURL: URL, profile: FFmpegProfile) -> String {
        let inputPath = item.originalURL.path
        let outputPath = outputURL.path
        
        switch item.targetFormat {
        case .mp4:
            var ffmpegCommand = "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? "
            switch profile {
            case .quality:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 15M -maxrate 20M -c:a aac -b:a 192k -movflags +faststart "
            case .speed:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 4M -maxrate 5M -c:a aac -b:a 96k -movflags +faststart "
            }
            ffmpegCommand += "-y \"\(outputPath)\""
            return ffmpegCommand
        case .mov:
            var ffmpegCommand = "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? "
            switch profile {
            case .quality:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 15M -maxrate 20M -c:a aac -b:a 192k "
            case .speed:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 4M -maxrate 5M -c:a aac -b:a 96k "
            }
            ffmpegCommand += "-y \"\(outputPath)\""
            return ffmpegCommand
        case .gif:
            var ffmpegCommand = "-i \"\(inputPath)\" -map 0:v:0 -an "
            switch profile {
            case .quality:
                ffmpegCommand += "-vf \"fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 "
            case .speed:
                ffmpegCommand += "-vf \"fps=8,scale=240:-1:flags=fast_bilinear,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 "
            }
            ffmpegCommand += "-y \"\(outputPath)\""
            return ffmpegCommand
        case .avi, .mkv:
            var ffmpegCommand = "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? "
            switch profile {
            case .quality:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 15M -maxrate 20M -c:a aac -b:a 192k "
            case .speed:
                ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v 4M -maxrate 5M -c:a aac -b:a 96k "
            }
            ffmpegCommand += "-y \"\(outputPath)\""
            return ffmpegCommand
        }
    }
    
    private func executeFFmpegCommand(
        _ command: String,
        outputURL: URL,
        stageLabel: String,
        duration: Double? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> ConversionAttemptResult {
        return await withCheckedContinuation { continuation in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(returning: .failure("转换会话未创建"))
                    return
                }
                
                let returnCode = session.getReturnCode()
                if ReturnCode.isSuccess(returnCode) {
                    continuation.resume(returning: .success)
                } else if ReturnCode.isCancel(returnCode) || self.shouldStopConversion {
                    try? FileManager.default.removeItem(at: outputURL)
                    continuation.resume(returning: .failure(Self.stoppedMessage))
                } else {
                    let logs = session.getAllLogsAsString() ?? "无日志"
                    let errorLog = session.getFailStackTrace() ?? "未知转换错误"
                    print("==== \(stageLabel) 失败 ====")
                    print("Command: \(command)")
                    print("Return Code: \(String(describing: returnCode))")
                    print("Fail StackTrace: \(errorLog)")
                    print("All Logs:\n\(logs)")
                    print("=========================")
                    try? FileManager.default.removeItem(at: outputURL)
                    let friendlyError = self.extractFriendlyErrorMessage(from: logs, stackTrace: errorLog)
                    continuation.resume(returning: .failure(friendlyError))
                }
            }, withLogCallback: nil, withStatisticsCallback: { stats in
                guard let stats, let duration, duration > 0 else { return }
                let timeInMilliseconds = Double(stats.getTime())
                guard timeInMilliseconds > 0 else { return }
                let progress = timeInMilliseconds / (duration * 1000.0)
                DispatchQueue.main.async {
                    progressHandler?(progress)
                }
            })
        }
    }
    
    // MARK: - 辅助方法
    private func overallProgress(for item: VideoItem) -> Double {
        switch item.status {
        case .pending:
            return 0.0
        case .converting:
            return item.conversionProgress
        case .success, .failed:
            return 1.0
        }
    }
    
    private func isFailed(status: VideoItem.ConversionStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
    
    private func extractFriendlyErrorMessage(from logs: String, stackTrace: String) -> String {
        let lowercasedLogs = logs.lowercased()
        if lowercasedLogs.contains("unknown encoder 'libx264'") {
            return "当前应用内置的转码器不支持 libx264，已切换为系统硬件编码器"
        } else if lowercasedLogs.contains("unknown encoder") {
            return "当前设备上的视频编码器不可用"
        } else if lowercasedLogs.contains("no space left on device") {
            return "设备存储空间不足"
        } else if lowercasedLogs.contains("permission denied") {
            return "文件权限被拒绝，无法读取原视频"
        } else if lowercasedLogs.contains("unsupported codec") || lowercasedLogs.contains("unknown decoder") {
            return "不支持的原视频编码格式"
        } else if lowercasedLogs.contains("error while opening encoder") {
            return "视频编码器初始化失败"
        } else if lowercasedLogs.contains("could not write header") || lowercasedLogs.contains("error initializing output stream") {
            return "输出文件封装失败，请尝试更换目标格式"
        } else if lowercasedLogs.contains("tag") && lowercasedLogs.contains("is not supported") {
            return "当前音视频编码与目标格式不兼容"
        } else if lowercasedLogs.contains("incorrect codec parameters") {
            return "源视频参数异常，暂时无法转换"
        } else if lowercasedLogs.contains("audio") && lowercasedLogs.contains("error") {
            return "音频轨处理失败"
        } else if lowercasedLogs.contains("format gif") && lowercasedLogs.contains("encoder manually") {
            return "GIF 不支持音频轨，已改为仅导出视频画面"
        } else if lowercasedLogs.contains("invalid data found") || lowercasedLogs.contains("moov atom not found") {
            return "视频文件已损坏或不完整"
        } else if lowercasedLogs.contains("conversion failed") {
            return "转码引擎内部错误"
        }
        
        if let detail = extractUsefulLogLine(from: logs, stackTrace: stackTrace) {
            return "转换失败：\(detail)"
        }
        
        return "转换失败，可能是不支持的特殊视频格式"
    }
    
    private func extractUsefulLogLine(from logs: String, stackTrace: String) -> String? {
        let candidates = (logs + "\n" + stackTrace)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let ignoredPrefixes = [
            "ffmpeg version",
            "built with",
            "configuration:",
            "libav",
            "input #",
            "metadata:",
            "duration:",
            "stream #",
            "side data:"
        ]
        
        for line in candidates.reversed() {
            let lowercasedLine = line.lowercased()
            let shouldIgnore = ignoredPrefixes.contains { lowercasedLine.hasPrefix($0) }
            if shouldIgnore {
                continue
            }
            
            if lowercasedLine.contains("error")
                || lowercasedLine.contains("failed")
                || lowercasedLine.contains("unsupported")
                || lowercasedLine.contains("unknown")
                || lowercasedLine.contains("invalid")
                || lowercasedLine.contains("denied") {
                return line
            }
        }
        
        return nil
    }
    
    private func generateThumbnail(from url: URL) async throws -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: time)
        return UIImage(cgImage: cgImage)
    }
    
    private func getVideoDuration(url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            return 0
        }
    }

    private func videoFileSize(for url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }
    
    func saveToPhotoLibrary() async -> Result<Int, Error> {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            return .failure(VideoConversionError.photoLibraryAccessDenied)
        }
        
        let successItems = videoItems.filter { $0.status == .success && $0.convertedFileURL != nil }
        let savableItems = successItems.filter { item in
            switch item.targetFormat {
            case .mp4, .mov, .gif:
                return true
            case .avi, .mkv:
                return false
            }
        }
        
        guard !savableItems.isEmpty else {
            return .failure(VideoConversionError.unsupportedPhotoLibraryFormat)
        }
        
        var savedCount = 0
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for item in savableItems {
                    guard let fileURL = item.convertedFileURL else { continue }
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let resourceType: PHAssetResourceType = item.targetFormat == .gif ? .photo : .video
                    creationRequest.addResource(with: resourceType, fileURL: fileURL, options: nil)
                    savedCount += 1
                }
            }
            return .success(savedCount)
        } catch {
            return .failure(mapPhotoLibraryError(error, containsGIF: savableItems.contains { $0.targetFormat == .gif }))
        }
    }
    
    private func mapPhotoLibraryError(_ error: Error, containsGIF: Bool) -> Error {
        let nsError = error as NSError
        if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3302 {
            if containsGIF {
                return VideoConversionError.gifPhotoLibrarySaveFailed
            }
            return VideoConversionError.photoLibrarySaveFailed
        }
        return error
    }
}

enum VideoConversionError: Error, LocalizedError {
    case photoLibraryAccessDenied
    case unsupportedPhotoLibraryFormat
    case photoLibrarySaveFailed
    case gifPhotoLibrarySaveFailed
    
    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied: return "需要相册的“添加照片”权限才能保存视频"
        case .unsupportedPhotoLibraryFormat: return "相册仅支持保存 MP4、MOV 和 GIF，请使用“保存到文件”导出其他格式"
        case .photoLibrarySaveFailed: return "保存到相册失败，请稍后重试"
        case .gifPhotoLibrarySaveFailed: return "GIF 保存到相册失败，请确认系统照片支持动画图片导入，或改用“保存到文件”"
        }
    }
}
