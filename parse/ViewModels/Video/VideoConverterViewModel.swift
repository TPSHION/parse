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
    @Published var videoItems: [VideoItem] = []
    
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
        let completed = successCount + failedCount
        return Double(completed) / Double(totalCount)
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
    
    func clearAll() {
        for item in videoItems {
            if let url = item.convertedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            try? FileManager.default.removeItem(at: item.originalURL)
        }
        videoItems.removeAll()
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
    
    // MARK: - 转换逻辑 (FFmpeg)
    func convertAll() async {
        isConverting = true
        defer { isConverting = false }
        
        for i in videoItems.indices {
            let item = videoItems[i]
            if item.status == .pending || isFailed(status: item.status) {
                await convertItem(at: i)
            }
        }
    }
    
    private func convertItem(at index: Int) async {
        let item = videoItems[index]
        videoItems[index].status = .converting
        videoItems[index].conversionProgress = 0.0
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let ext = item.targetFormat.fileExtension
        let fileName = "\(item.originalName)_\(UUID().uuidString.prefix(6)).\(ext)"
        let outputURL = tempDirectory.appendingPathComponent(fileName)
        
        // 构建 FFmpeg 命令
        let inputPath = item.originalURL.path
        let outputPath = outputURL.path
        
        var ffmpegCommand = "-i \"\(inputPath)\" "
        // 只保留主视频流和可选音频流，避免 MOV 内的 metadata/data 轨道影响 MP4 封装
        ffmpegCommand += "-map 0:v:0 -map 0:a? "
        
        // 针对特定格式优化命令
        switch item.targetFormat {
        case .mp4:
            // ffmpeg-kit iOS 预编译包通常不包含 libx264，改用系统硬件编码器 videotoolbox
            ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "
        case .mov:
            ffmpegCommand += "-c copy "
        case .gif:
            // 生成高质量 GIF 的调色板方法
            ffmpegCommand += "-vf \"fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 "
        case .avi, .mkv:
            // 默认转换同样避免依赖未编入的 libx264
            ffmpegCommand += "-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -c:a aac "
        }
        
        ffmpegCommand += "-y \"\(outputPath)\""
        
        // 获取视频总时长以计算进度
        let duration = await getVideoDuration(url: item.originalURL)
        
        return await withCheckedContinuation { continuation in
            FFmpegKit.executeAsync(ffmpegCommand, withCompleteCallback: { [weak self] session in
                guard let self = self, let session = session else {
                    continuation.resume()
                    return
                }
                
                let returnCode = session.getReturnCode()
                DispatchQueue.main.async {
                    if ReturnCode.isSuccess(returnCode) {
                        self.videoItems[index].convertedFileURL = outputURL
                        self.videoItems[index].status = .success
                        self.videoItems[index].conversionProgress = 1.0
                    } else {
                        // 提取并打印 FFmpeg 错误日志
                        let logs = session.getAllLogsAsString() ?? "无日志"
                        let errorLog = session.getFailStackTrace() ?? "未知转换错误"
                        print("==== FFmpeg 转换失败 ====")
                        print("Return Code: \(String(describing: returnCode))")
                        print("Fail StackTrace: \(errorLog)")
                        print("All Logs:\n\(logs)")
                        print("===========================")
                        
                        // 提取一条对用户相对友好的错误信息
                        let friendlyError = self.extractFriendlyErrorMessage(from: logs)
                        
                        self.videoItems[index].status = .failed(friendlyError)
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    continuation.resume()
                }
            }, withLogCallback: nil, withStatisticsCallback: { [weak self] stats in
                guard let self = self, let stats = stats, duration > 0 else { return }
                
                let timeInMilliseconds = Double(stats.getTime())
                if timeInMilliseconds > 0 {
                    let progress = timeInMilliseconds / (duration * 1000.0)
                    DispatchQueue.main.async {
                        // 确保进度不倒退且不超过 0.99 (留给完成回调)
                        let safeProgress = min(max(progress, self.videoItems[index].conversionProgress), 0.99)
                        self.videoItems[index].conversionProgress = safeProgress
                    }
                }
            })
        }
    }
    
    // MARK: - 辅助方法
    private func isFailed(status: VideoItem.ConversionStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
    
    private func extractFriendlyErrorMessage(from logs: String) -> String {
        let lowercasedLogs = logs.lowercased()
        if lowercasedLogs.contains("unknown encoder 'libx264'") {
            return "当前应用内置的转码器不支持 libx264，已切换为系统硬件编码器"
        } else if lowercasedLogs.contains("no space left on device") {
            return "设备存储空间不足"
        } else if lowercasedLogs.contains("permission denied") {
            return "文件权限被拒绝，无法读取原视频"
        } else if lowercasedLogs.contains("unsupported codec") || lowercasedLogs.contains("unknown decoder") {
            return "不支持的原视频编码格式"
        } else if lowercasedLogs.contains("invalid data found") || lowercasedLogs.contains("moov atom not found") {
            return "视频文件已损坏或不完整"
        } else if lowercasedLogs.contains("conversion failed") {
            return "转码引擎内部错误"
        }
        return "转换失败，可能是不支持的特殊视频格式"
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
        var savedCount = 0
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for item in successItems {
                    guard let fileURL = item.convertedFileURL else { continue }
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .video, fileURL: fileURL, options: nil)
                    savedCount += 1
                }
            }
            return .success(savedCount)
        } catch {
            return .failure(error)
        }
    }
}

enum VideoConversionError: Error, LocalizedError {
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied: return "需要相册的“添加照片”权限才能保存视频"
        }
    }
}
