import AVFoundation
import Combine
import Foundation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit
import ffmpegkit

@MainActor
final class MediaCompressorViewModel: ObservableObject {
    @Published var items: [MediaCompressionItem] = []
    @Published var exportDocument: ConvertedMediaDocument?
    @Published var compressionLevel: MediaCompressionLevel = .balanced
    @Published var isImporting = false
    @Published var isCompressing = false

    private var importActivityCount = 0

    var totalCount: Int { items.count }
    var pendingCount: Int { items.filter { $0.status == .pending }.count }
    var successCount: Int { items.filter { $0.status == .success }.count }
    var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }
    var compressingCount: Int { items.filter { $0.status == .compressing }.count }
    var readyCount: Int { items.filter { isReady(status: $0.status) }.count }

    var overallProgress: Double {
        guard !items.isEmpty else { return 0.0 }
        let totalProgress = items.reduce(0.0) { $0 + progressValue(for: $1) }
        return totalProgress / Double(items.count)
    }

    var canImport: Bool {
        !isCompressing
    }

    var canCompress: Bool {
        !isCompressing && readyCount > 0
    }

    var hasSuccessItems: Bool {
        items.contains { $0.status == .success }
    }

    var canSave: Bool {
        hasSuccessItems && !isCompressing && !isImporting
    }

    var successfulItems: [MediaCompressionItem] {
        items.filter { $0.status == .success && $0.outputURL != nil }
    }

    var shareableURLs: [URL] {
        items.compactMap { item in
            item.status == .success ? item.outputURL : nil
        }
    }

    func shareableURLs(for selectedItemIDs: Set<UUID>) -> [URL] {
        successfulItems.compactMap { item in
            selectedItemIDs.contains(item.id) ? item.outputURL : nil
        }
    }

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            beginImport()
            Task {
                defer { endImport() }
                await importFiles(from: urls)
            }
        case .failure(let error):
            print("Media import failed: \(error.localizedDescription)")
        }
    }

    func processPhotoLibrarySelections(_ selections: [PhotosPickerItem]) {
        guard !selections.isEmpty else { return }
        beginImport()

        Task { [weak self] in
            guard let self else { return }
            defer { endImport() }

            for selection in selections {
                do {
                    if let imageFile = try await selection.loadTransferable(type: ImageFileTransferable.self) {
                        let imported = ImportedMediaSource(
                            url: imageFile.url,
                            originalFilename: imageFile.originalFilename
                        )
                        if let item = await makeItem(from: imported) {
                            items.append(item)
                        } else {
                            try? FileManager.default.removeItem(at: imageFile.url)
                        }
                        continue
                    }

                    if let movie = try await selection.loadTransferable(type: MovieTransferable.self) {
                        let imported = ImportedMediaSource(
                            url: movie.url,
                            originalFilename: movie.originalFilename
                        )
                        if let item = await makeItem(from: imported) {
                            items.append(item)
                        } else {
                            try? FileManager.default.removeItem(at: movie.url)
                        }
                    }
                } catch {
                    print("Failed to import photo library media for compression: \(error.localizedDescription)")
                }
            }
        }
    }

    func removeItem(id: UUID) {
        guard !isCompressing else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let outputURL = items[index].outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        try? FileManager.default.removeItem(at: items[index].originalURL)
        items.remove(at: index)
    }

    func clearAll() {
        guard !isCompressing else { return }
        for item in items {
            if let outputURL = item.outputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try? FileManager.default.removeItem(at: item.originalURL)
        }
        items.removeAll()
    }

    func prepareExportDocument() {
        let successItems = successfulItems
        exportDocument = successItems.isEmpty ? nil : ConvertedMediaDocument(items: successItems)
    }

    func prepareExportDocument(for selectedItemIDs: Set<UUID>) {
        let selectedItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        exportDocument = selectedItems.isEmpty ? nil : ConvertedMediaDocument(items: selectedItems)
    }

    func startCompression() async {
        guard canCompress else { return }

        isCompressing = true
        defer { isCompressing = false }

        let selectedLevel = compressionLevel
        let targetIndexes = items.indices.filter { isReady(status: items[$0].status) }
        for index in targetIndexes {
            await compressItem(at: index, level: selectedLevel)
        }
    }

    func saveToPhotoLibrary() async -> Result<MediaCompressionPhotoLibrarySaveSummary, Error> {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            return .failure(MediaCompressionSaveError.photoLibraryAccessDenied)
        }

        let successItems = items.filter { $0.status == .success && $0.outputURL != nil }
        let savableItems = successItems.filter(Self.canSaveToPhotoLibrary(_:))

        guard !savableItems.isEmpty else {
            return .failure(MediaCompressionSaveError.unsupportedPhotoLibraryFormat)
        }

        let skippedCount = successItems.count - savableItems.count
        var savedCount = 0

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for item in savableItems {
                    guard let fileURL = item.outputURL else { continue }
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let resourceType: PHAssetResourceType = Self.photoLibraryResourceType(for: item)
                    creationRequest.addResource(with: resourceType, fileURL: fileURL, options: nil)
                    savedCount += 1
                }
            }

            return .success(
                MediaCompressionPhotoLibrarySaveSummary(
                    savedCount: savedCount,
                    skippedCount: skippedCount
                )
            )
        } catch {
            let containsGIF = savableItems.contains { $0.type == .video && $0.originalExtension.lowercased() == "gif" }
            return .failure(mapPhotoLibraryError(error, containsGIF: containsGIF))
        }
    }

    func saveToPhotoLibrary(selectedItemIDs: Set<UUID>) async -> Result<MediaCompressionPhotoLibrarySaveSummary, Error> {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            return .failure(MediaCompressionSaveError.photoLibraryAccessDenied)
        }

        let selectedItems = successfulItems.filter { selectedItemIDs.contains($0.id) }
        let savableItems = selectedItems.filter(Self.canSaveToPhotoLibrary(_:))

        guard !savableItems.isEmpty else {
            return .failure(MediaCompressionSaveError.unsupportedPhotoLibraryFormat)
        }

        let skippedCount = selectedItems.count - savableItems.count
        var savedCount = 0

        do {
            try await PHPhotoLibrary.shared().performChanges {
                for item in savableItems {
                    guard let fileURL = item.outputURL else { continue }
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let resourceType: PHAssetResourceType = Self.photoLibraryResourceType(for: item)
                    creationRequest.addResource(with: resourceType, fileURL: fileURL, options: nil)
                    savedCount += 1
                }
            }

            return .success(
                MediaCompressionPhotoLibrarySaveSummary(
                    savedCount: savedCount,
                    skippedCount: skippedCount
                )
            )
        } catch {
            let containsGIF = savableItems.contains { $0.type == .video && $0.originalExtension.lowercased() == "gif" }
            return .failure(mapPhotoLibraryError(error, containsGIF: containsGIF))
        }
    }

    private func importFiles(from urls: [URL]) async {
        for url in urls {
            guard let imported = Self.copyImportedFile(from: url) else { continue }

            if let item = await makeItem(from: imported) {
                items.append(item)
            } else {
                try? FileManager.default.removeItem(at: imported.url)
            }
        }
    }

    private func makeItem(from imported: ImportedMediaSource) async -> MediaCompressionItem? {
        let filename = imported.originalFilename
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let fileSize = Self.fileSize(at: imported.url)

        if ImageFormat(fileExtension: fileExtension) != nil {
            let preview = await loadImagePreview(from: imported.url)
            let pixelSize = imagePixelSize(for: imported.url)
            return MediaCompressionItem(
                type: .image,
                originalURL: imported.url,
                filename: filename,
                baseName: baseName,
                originalExtension: fileExtension,
                originalSizeInBytes: fileSize,
                previewImage: preview,
                duration: nil,
                pixelSize: pixelSize
            )
        }

        if VideoFormat(fileExtension: fileExtension) != nil {
            let thumbnail = await generateVideoThumbnail(from: imported.url)
            let duration = await videoDuration(for: imported.url)
            return MediaCompressionItem(
                type: .video,
                originalURL: imported.url,
                filename: filename,
                baseName: baseName,
                originalExtension: fileExtension,
                originalSizeInBytes: fileSize,
                previewImage: thumbnail,
                duration: duration,
                pixelSize: nil
            )
        }

        if AudioFormat(fileExtension: fileExtension) != nil {
            return MediaCompressionItem(
                type: .audio,
                originalURL: imported.url,
                filename: filename,
                baseName: baseName,
                originalExtension: fileExtension,
                originalSizeInBytes: fileSize,
                previewImage: nil,
                duration: nil,
                pixelSize: nil
            )
        }

        return nil
    }

    private func compressItem(at index: Int, level: MediaCompressionLevel) async {
        guard items.indices.contains(index) else { return }

        let item = items[index]
        items[index].status = .compressing
        items[index].compressionProgress = 0.0

        let outputURL = makeOutputURL(for: item)

        do {
            let compressedSize: Int64
            switch item.type {
            case .image:
                compressedSize = try await compressImage(item, to: outputURL, level: level)
            case .video:
                compressedSize = try await compressVideo(item, to: outputURL, level: level)
            case .audio:
                compressedSize = try await compressAudio(item, to: outputURL, level: level)
            }

            guard let latestIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[latestIndex].outputURL = outputURL
            items[latestIndex].compressedSizeInBytes = compressedSize
            items[latestIndex].compressionProgress = 1.0
            items[latestIndex].status = .success
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            guard let latestIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[latestIndex].outputURL = nil
            items[latestIndex].compressedSizeInBytes = nil
            items[latestIndex].compressionProgress = 0.0
            items[latestIndex].status = .failed(error.localizedDescription)
        }
    }

    private func compressImage(
        _ item: MediaCompressionItem,
        to outputURL: URL,
        level: MediaCompressionLevel
    ) async throws -> Int64 {
        guard let format = ImageFormat(fileExtension: item.originalExtension) else {
            throw MediaCompressionError.unsupportedFormat
        }

        let maxDimension = level.imageMaxDimension
        let compressionQuality = level.imageCompressionQuality
        let utTypeIdentifier = format.utType.identifier

        let fileSize = try await Task.detached(priority: .userInitiated) { () throws -> Int64 in
            guard let image = UIImage(contentsOfFile: item.originalURL.path) else {
                throw MediaCompressionError.failedToLoadSource
            }

            let resizedImage = Self.resizedImage(image, maxDimension: maxDimension)

            switch format {
            case .jpeg:
                guard let data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
                    throw MediaCompressionError.failedToCreateDestination
                }
                try data.write(to: outputURL)
            case .png:
                guard let data = resizedImage.pngData() else {
                    throw MediaCompressionError.failedToCreateDestination
                }
                try data.write(to: outputURL)
            case .heic:
                try Self.writeCGImage(
                    resizedImage,
                    to: outputURL,
                    utTypeIdentifier: utTypeIdentifier,
                    properties: [kCGImageDestinationLossyCompressionQuality: compressionQuality]
                )
            case .tiff:
                try Self.writeCGImage(
                    resizedImage,
                    to: outputURL,
                    utTypeIdentifier: utTypeIdentifier,
                    properties: [kCGImagePropertyTIFFCompression: 5]
                )
            }

            let compressedSize = Self.fileSize(at: outputURL)
            guard compressedSize > 0 else {
                throw MediaCompressionError.failedToCreateDestination
            }
            guard compressedSize < item.originalSizeInBytes else {
                throw MediaCompressionError.noCompressionBenefit
            }
            return compressedSize
        }.value

        return fileSize
    }

    private func compressVideo(
        _ item: MediaCompressionItem,
        to outputURL: URL,
        level: MediaCompressionLevel
    ) async throws -> Int64 {
        guard let format = VideoFormat(fileExtension: item.originalExtension) else {
            throw MediaCompressionError.unsupportedFormat
        }

        let command = buildVideoCompressionCommand(
            inputURL: item.originalURL,
            outputURL: outputURL,
            format: format,
            level: level
        )

        try await executeFFmpegCommand(
            command,
            outputURL: outputURL,
            duration: item.duration
        ) { [weak self] progress in
            Task { @MainActor in
                self?.applyProgress(progress, for: item.id)
            }
        }

        let compressedSize = Self.fileSize(at: outputURL)
        guard compressedSize < item.originalSizeInBytes else {
            throw MediaCompressionError.noCompressionBenefit
        }
        return compressedSize
    }

    private func compressAudio(
        _ item: MediaCompressionItem,
        to outputURL: URL,
        level: MediaCompressionLevel
    ) async throws -> Int64 {
        guard let format = AudioFormat(fileExtension: item.originalExtension) else {
            throw MediaCompressionError.unsupportedFormat
        }

        let duration = await audioDuration(for: item.originalURL)
        let command = buildAudioCompressionCommand(
            inputURL: item.originalURL,
            outputURL: outputURL,
            format: format,
            level: level
        )

        try await executeFFmpegCommand(
            command,
            outputURL: outputURL,
            duration: duration
        ) { [weak self] progress in
            Task { @MainActor in
                self?.applyProgress(progress, for: item.id)
            }
        }

        let compressedSize = Self.fileSize(at: outputURL)
        guard compressedSize < item.originalSizeInBytes else {
            throw MediaCompressionError.noCompressionBenefit
        }
        return compressedSize
    }

    private func buildVideoCompressionCommand(
        inputURL: URL,
        outputURL: URL,
        format: VideoFormat,
        level: MediaCompressionLevel
    ) -> String {
        let inputPath = inputURL.path
        let outputPath = outputURL.path

        switch format {
        case .gif:
            let fps = level.videoFPS ?? 12
            let width = min(level.videoScaleWidth, 960)
            return "-i \"\(inputPath)\" -map 0:v:0 -an -vf \"fps=\(fps),scale=\(width):-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 -y \"\(outputPath)\""
        case .avi:
            let videoFilters = videoFilterArguments(for: level)
            return "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? \(videoFilters)-c:v mpeg4 -q:v \(level == .light ? 4 : (level == .balanced ? 6 : 8)) -c:a libmp3lame -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) -y \"\(outputPath)\""
        case .mp4, .mov, .mkv:
            let videoFilters = videoFilterArguments(for: level)
            let fastStart = format == .mp4 || format == .mov ? "-movflags +faststart " : ""
            return "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? \(videoFilters)-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v \(level.videoBitrate) -maxrate \(level.videoMaxRate) -c:a aac -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) \(fastStart)-y \"\(outputPath)\""
        case .ts:
            let videoFilters = videoFilterArguments(for: level)
            return "-i \"\(inputPath)\" -map 0:v:0 -map 0:a? \(videoFilters)-c:v h264_videotoolbox -allow_sw 1 -pix_fmt yuv420p -b:v \(level.videoBitrate) -maxrate \(level.videoMaxRate) -c:a aac -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) -f mpegts -y \"\(outputPath)\""
        }
    }

    private func buildAudioCompressionCommand(
        inputURL: URL,
        outputURL: URL,
        format: AudioFormat,
        level: MediaCompressionLevel
    ) -> String {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        let prefix = "-i \"\(inputPath)\" -map 0:a:0 -vn -map_metadata 0 "

        switch format {
        case .mp3:
            return "\(prefix)-c:a libmp3lame -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) -y \"\(outputPath)\""
        case .wav:
            let codec = level == .light ? "pcm_s24le" : "pcm_s16le"
            return "\(prefix)-c:a \(codec) -ar \(level.audioSampleRate) -y \"\(outputPath)\""
        case .aac:
            return "\(prefix)-c:a aac -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) -f adts -y \"\(outputPath)\""
        case .m4a:
            return "\(prefix)-c:a aac -b:a \(level.audioBitrate) -ar \(level.audioSampleRate) -movflags +faststart -y \"\(outputPath)\""
        case .flac:
            return "\(prefix)-c:a flac -compression_level \(level.flacCompressionLevel) -sample_fmt s16 -ar \(level.audioSampleRate) -y \"\(outputPath)\""
        }
    }

    private func videoFilterArguments(for level: MediaCompressionLevel) -> String {
        var filters = [
            "scale='if(gt(iw,\(level.videoScaleWidth)),\(level.videoScaleWidth),iw)':-2:flags=lanczos"
        ]
        if let fps = level.videoFPS {
            filters.insert("fps=\(fps)", at: 0)
        }
        return "-vf \"\(filters.joined(separator: ","))\" "
    }

    private func executeFFmpegCommand(
        _ command: String,
        outputURL: URL,
        duration: Double?,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(throwing: MediaCompressionError.sessionUnavailable)
                    return
                }

                let returnCode = session.getReturnCode()
                if ReturnCode.isSuccess(returnCode) {
                    continuation.resume(returning: ())
                    return
                }

                try? FileManager.default.removeItem(at: outputURL)
                let logs = session.getAllLogsAsString() ?? ""
                let stackTrace = session.getFailStackTrace() ?? ""
                let message = Self.extractFriendlyFFmpegMessage(from: logs, stackTrace: stackTrace)
                continuation.resume(throwing: MediaCompressionError.ffmpegFailed(message))
            }, withLogCallback: nil, withStatisticsCallback: { statistics in
                guard
                    let statistics,
                    let duration,
                    duration > 0
                else {
                    return
                }

                let timeInMilliseconds = Double(statistics.getTime())
                guard timeInMilliseconds > 0 else { return }
                let progress = min(max(timeInMilliseconds / (duration * 1000.0), 0.0), 0.99)
                progressHandler(progress)
            })
        }
    }

    private func applyProgress(_ progress: Double, for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].compressionProgress = min(max(progress, items[index].compressionProgress), 0.99)
    }

    private func makeOutputURL(for item: MediaCompressionItem) -> URL {
        let fileName = "\(item.baseName)_compressed_\(UUID().uuidString.prefix(6)).\(item.originalExtension)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func beginImport() {
        importActivityCount += 1
        isImporting = importActivityCount > 0
    }

    private func endImport() {
        importActivityCount = max(0, importActivityCount - 1)
        isImporting = importActivityCount > 0
    }

    private func isReady(status: MediaCompressionItem.CompressionStatus) -> Bool {
        switch status {
        case .pending, .failed:
            return true
        case .compressing, .success:
            return false
        }
    }

    private func progressValue(for item: MediaCompressionItem) -> Double {
        switch item.status {
        case .pending:
            return 0.0
        case .compressing:
            return item.compressionProgress
        case .success, .failed:
            return 1.0
        }
    }

    private func loadImagePreview(from url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(contentsOfFile: url.path)
        }.value
    }

    private func generateVideoThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: .zero) { image, _, error in
                guard error == nil, let image else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: image))
            }
        }
    }

    private func videoDuration(for url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds.isFinite ? max(duration.seconds, 0) : 0
        } catch {
            return 0
        }
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

    private func imagePixelSize(for url: URL) -> CGSize? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    private func mapPhotoLibraryError(_ error: Error, containsGIF: Bool) -> Error {
        let nsError = error as NSError
        if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3302 {
            if containsGIF {
                return MediaCompressionSaveError.gifPhotoLibrarySaveFailed
            }
            return MediaCompressionSaveError.photoLibrarySaveFailed
        }
        return error
    }

    nonisolated private static func canSaveToPhotoLibrary(_ item: MediaCompressionItem) -> Bool {
        item.supportsPhotoLibrarySave
    }

    nonisolated private static func photoLibraryResourceType(for item: MediaCompressionItem) -> PHAssetResourceType {
        if item.type == .video && item.originalExtension.lowercased() != "gif" {
            return .video
        }
        return .photo
    }

    nonisolated private static func copyImportedFile(from url: URL) -> ImportedMediaSource? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            return ImportedMediaSource(url: tempURL, originalFilename: url.lastPathComponent)
        } catch {
            print("Failed to import file for compression: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        let longestSide = max(originalSize.width, originalSize.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(
            width: floor(originalSize.width * scale),
            height: floor(originalSize.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated private static func writeCGImage(
        _ image: UIImage,
        to outputURL: URL,
        utTypeIdentifier: String,
        properties: [CFString: Any]
    ) throws {
        guard let cgImage = image.cgImage else {
            throw MediaCompressionError.failedToLoadSource
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            utTypeIdentifier as CFString,
            1,
            nil
        ) else {
            throw MediaCompressionError.failedToCreateDestination
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaCompressionError.failedToCreateDestination
        }
    }

    nonisolated private static func fileSize(at url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return 0
        }
    }

    nonisolated private static func extractFriendlyFFmpegMessage(from logs: String, stackTrace: String) -> String {
        let lowercasedLogs = logs.lowercased()

        if lowercasedLogs.contains("no such file or directory") {
            return AppLocalizer.localized("源文件不存在或已被移除")
        }
        if lowercasedLogs.contains("permission denied") {
            return AppLocalizer.localized("没有读取或写入该文件的权限")
        }
        if lowercasedLogs.contains("invalid data found") || lowercasedLogs.contains("moov atom not found") {
            return AppLocalizer.localized("源文件已损坏或内容不完整")
        }
        if lowercasedLogs.contains("unknown encoder") {
            return AppLocalizer.localized("当前设备上的压缩编码器不可用")
        }
        if lowercasedLogs.contains("unsupported codec") || lowercasedLogs.contains("unknown decoder") {
            return AppLocalizer.localized("不支持的原始编码格式")
        }
        if lowercasedLogs.contains("could not write header") || lowercasedLogs.contains("error initializing output stream") {
            return AppLocalizer.localized("压缩输出文件写入失败")
        }
        if lowercasedLogs.contains("no space left on device") {
            return AppLocalizer.localized("设备存储空间不足")
        }

        let candidates = (logs + "\n" + stackTrace)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in candidates.reversed() {
            let lowercasedLine = line.lowercased()
            if lowercasedLine.contains("error")
                || lowercasedLine.contains("failed")
                || lowercasedLine.contains("unsupported")
                || lowercasedLine.contains("unknown")
                || lowercasedLine.contains("invalid")
                || lowercasedLine.contains("denied") {
                return AppLocalizer.formatted("压缩失败：%@", line)
            }
        }

        return AppLocalizer.localized("压缩失败，可能是不支持的特殊媒体格式")
    }
}

private struct ImportedMediaSource {
    let url: URL
    let originalFilename: String
}
