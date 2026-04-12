import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum TransferResultCategory: String, CaseIterable {
    case imageConversion = "image_conversion"
    case videoConversion = "video_conversion"
    case audioConversion = "audio_conversion"
    case compression = "compression"
    case textRecognition = "text_recognition"
    case ebookConversion = "ebook_conversion"

    nonisolated var folderName: String { rawValue }

    nonisolated var displayTitle: String {
        switch self {
        case .imageConversion:
            return AppLocalizer.localized("图片转换")
        case .videoConversion:
            return AppLocalizer.localized("视频转换")
        case .audioConversion:
            return AppLocalizer.localized("音频转换")
        case .compression:
            return AppLocalizer.localized("压缩结果")
        case .textRecognition:
            return AppLocalizer.localized("文字识别")
        case .ebookConversion:
            return AppLocalizer.localized("电子书转换")
        }
    }
}

struct TransferArchivedResultItem: Identifiable {
    let category: TransferResultCategory
    let fileURL: URL
    let filename: String
    let fileSize: Int64
    let modifiedAt: Date?

    var id: String {
        "\(category.rawValue)::\(filename)"
    }
}

struct TransferArchivedResultSection: Identifiable {
    let category: TransferResultCategory
    let items: [TransferArchivedResultItem]

    var id: String {
        category.rawValue
    }

    var title: String {
        category.displayTitle
    }

    var count: Int {
        items.count
    }
}

enum TransferResultPreviewKind: String {
    case image
    case video
    case none
}

enum TransferResultArchiveService {
    nonisolated private static let rootFolderName = "TransferResults"
    nonisolated private static let thumbnailFolderName = "thumbnails"

    nonisolated static func scheduleArchive(url: URL, category: TransferResultCategory) {
        Task.detached(priority: .utility) {
            try? archive(url: url, category: category)
        }
    }

    nonisolated static func archiveImmediately(url: URL, category: TransferResultCategory) throws {
        try archive(url: url, category: category)
    }

    nonisolated static func allPayload() -> [[String: Any]] {
        TransferResultCategory.allCases.map { category in
            let items = archivedItems(for: category).map { item in
                let previewKind = previewKind(for: item.fileURL)
                return [
                    "name": item.filename,
                    "bytes": item.fileSize,
                    "modifiedAt": item.modifiedAt?.ISO8601Format() ?? "",
                    "downloadURL": "/api/results/download?category=\(category.rawValue)&name=\(urlEncoded(item.filename))",
                    "previewKind": previewKind.rawValue,
                    "thumbnailURL": previewKind == .none ? "" : "/api/results/thumbnail?category=\(category.rawValue)&name=\(urlEncoded(item.filename))"
                ]
            }

            return [
                "key": category.rawValue,
                "title": category.displayTitle,
                "count": items.count,
                "items": items
            ]
        }
    }

    nonisolated static func allSections() -> [TransferArchivedResultSection] {
        TransferResultCategory.allCases.map { category in
            TransferArchivedResultSection(
                category: category,
                items: archivedItems(for: category)
            )
        }
    }

    nonisolated static func resultFileURL(categoryRawValue: String, filename: String) -> URL? {
        guard
            let category = TransferResultCategory(rawValue: categoryRawValue),
            isValidFilename(filename)
        else {
            return nil
        }

        let fileURL = resultsDirectory(for: category).appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    nonisolated static func deleteResult(categoryRawValue: String, filename: String) throws {
        guard let fileURL = resultFileURL(categoryRawValue: categoryRawValue, filename: filename) else {
            throw NSError(domain: "TransferResultArchiveService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Result file not found"
            ])
        }
        try FileManager.default.removeItem(at: fileURL)
        try? removeThumbnailCache(for: fileURL)
    }

    nonisolated static func deleteAllResults(in category: TransferResultCategory) throws {
        let directory = resultsDirectory(for: category)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            try FileManager.default.removeItem(at: url)
        }

        let thumbnailDirectory = thumbnailsDirectory(for: category)
        if FileManager.default.fileExists(atPath: thumbnailDirectory.path) {
            try FileManager.default.removeItem(at: thumbnailDirectory)
        }
    }

    nonisolated static func thumbnailData(categoryRawValue: String, filename: String) async -> (data: Data, mimeType: String)? {
        guard let fileURL = resultFileURL(categoryRawValue: categoryRawValue, filename: filename) else {
            return nil
        }

        switch previewKind(for: fileURL) {
        case .image:
            return imageThumbnailData(for: fileURL)
        case .video:
            if let cached = cachedThumbnailData(for: fileURL) {
                return cached
            }
            if let generated = await videoThumbnailData(for: fileURL) {
                persistThumbnailCache(data: generated.data, for: fileURL)
                return generated
            }
            return placeholderThumbnailData(for: fileURL, kind: .video)
        case .none:
            return nil
        }
    }

    nonisolated static func thumbnailImage(for fileURL: URL) async -> UIImage? {
        switch previewKind(for: fileURL) {
        case .image:
            guard let imageData = imageThumbnailData(for: fileURL)?.data else { return nil }
            return UIImage(data: imageData)
        case .video:
            if let cached = cachedThumbnailData(for: fileURL)?.data {
                return UIImage(data: cached)
            }
            guard let generated = await videoThumbnailData(for: fileURL) else { return nil }
            persistThumbnailCache(data: generated.data, for: fileURL)
            let imageData = generated.data
            return UIImage(data: imageData)
        case .none:
            return nil
        }
    }

    nonisolated private static func archive(url: URL, category: TransferResultCategory) throws {
        let fileManager = FileManager.default
        let destinationDirectory = resultsDirectory(for: category)
        try createDirectoryIfNeeded(destinationDirectory)

        let destinationURL = uniqueDestinationURL(
            for: url.lastPathComponent,
            in: destinationDirectory
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        if previewKind(for: destinationURL) == .video {
            Task.detached(priority: .utility) {
                guard let generated = await videoThumbnailData(for: destinationURL) else { return }
                persistThumbnailCache(data: generated.data, for: destinationURL)
            }
        }
    }

    nonisolated private static func archivedItems(for category: TransferResultCategory) -> [TransferArchivedResultItem] {
        let directory = resultsDirectory(for: category)
        let fileManager = FileManager.default

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                values.isRegularFile == true
            else {
                return nil
            }

            return TransferArchivedResultItem(
                category: category,
                fileURL: url,
                filename: url.lastPathComponent,
                fileSize: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate
            )
        }
        .sorted { lhs, rhs in
            let lhsDate = lhs.modifiedAt ?? .distantPast
            let rhsDate = rhs.modifiedAt ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
        }
    }

    nonisolated private static func resultsDirectory(for category: TransferResultCategory) -> URL {
        rootDirectory.appendingPathComponent(category.folderName, isDirectory: true)
    }

    nonisolated private static func thumbnailsDirectory(for category: TransferResultCategory) -> URL {
        resultsDirectory(for: category).appendingPathComponent(thumbnailFolderName, isDirectory: true)
    }

    nonisolated private static var rootDirectory: URL {
        let baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory.appendingPathComponent(rootFolderName, isDirectory: true)
    }

    nonisolated private static func createDirectoryIfNeeded(_ directory: URL) throws {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func thumbnailCacheURL(for fileURL: URL) -> URL? {
        guard let category = category(for: fileURL) else { return nil }
        let basename = fileURL.deletingPathExtension().lastPathComponent
        return thumbnailsDirectory(for: category).appendingPathComponent("\(basename).jpg")
    }

    nonisolated private static func cachedThumbnailData(for fileURL: URL) -> (data: Data, mimeType: String)? {
        guard
            let cacheURL = thumbnailCacheURL(for: fileURL),
            let data = try? Data(contentsOf: cacheURL)
        else {
            return nil
        }
        return (data, "image/jpeg")
    }

    nonisolated private static func persistThumbnailCache(data: Data, for fileURL: URL) {
        guard let cacheURL = thumbnailCacheURL(for: fileURL) else { return }
        do {
            try createDirectoryIfNeeded(cacheURL.deletingLastPathComponent())
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            return
        }
    }

    nonisolated private static func removeThumbnailCache(for fileURL: URL) throws {
        guard let cacheURL = thumbnailCacheURL(for: fileURL) else { return }
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
        }
    }

    nonisolated private static func category(for fileURL: URL) -> TransferResultCategory? {
        let folderName = fileURL.deletingLastPathComponent().lastPathComponent
        if folderName == thumbnailFolderName {
            let categoryFolder = fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            return TransferResultCategory(rawValue: categoryFolder)
        }
        return TransferResultCategory(rawValue: folderName)
    }

    nonisolated private static func uniqueDestinationURL(for filename: String, in directory: URL) -> URL {
        let candidate = directory.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: candidate.path) else {
            let ext = candidate.pathExtension
            let baseName = candidate.deletingPathExtension().lastPathComponent

            for index in 1...999 {
                let renamed = ext.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(ext)"
                let url = directory.appendingPathComponent(renamed)
                if !FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }

            return directory.appendingPathComponent(UUID().uuidString + "-" + filename)
        }
        return candidate
    }

    nonisolated private static func isValidFilename(_ filename: String) -> Bool {
        !filename.isEmpty &&
        !filename.contains("/") &&
        !filename.contains("\\") &&
        filename == URL(fileURLWithPath: filename).lastPathComponent
    }

    nonisolated private static func urlEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    nonisolated static func previewKind(for fileURL: URL) -> TransferResultPreviewKind {
        let ext = fileURL.pathExtension.lowercased()
        if ["ts", "mts", "m2ts"].contains(ext) {
            return .video
        }
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return .none
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        return .none
    }

    nonisolated private static func imageThumbnailData(for fileURL: URL) -> (data: Data, mimeType: String)? {
        guard
            let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 420,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
            )
        else {
            return nil
        }

        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return (mutableData as Data, "image/jpeg")
    }

    nonisolated private static func videoThumbnailData(for fileURL: URL) async -> (data: Data, mimeType: String)? {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 420, height: 420)
        generator.requestedTimeToleranceAfter = .positiveInfinity
        generator.requestedTimeToleranceBefore = .zero

        let candidateTimes: [CMTime] = [
            .zero,
            CMTime(seconds: 0.1, preferredTimescale: 600),
            CMTime(seconds: 0.5, preferredTimescale: 600),
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime(seconds: 2.0, preferredTimescale: 600)
        ]

        var renderedImage: CGImage?
        for time in candidateTimes {
            if let image = try? await generator.image(at: time).image {
                renderedImage = image
                break
            }
        }

        guard let image = renderedImage else {
            return nil
        }

        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return (mutableData as Data, "image/jpeg")
    }

    nonisolated private static func placeholderThumbnailData(for fileURL: URL, kind: TransferResultPreviewKind) -> (data: Data, mimeType: String)? {
        let label: String
        switch kind {
        case .video:
            label = "VIDEO"
        case .image:
            label = "IMAGE"
        case .none:
            label = fileURL.pathExtension.uppercased()
        }

        let safeLabel = label.isEmpty ? "FILE" : label
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="420" height="280" viewBox="0 0 420 280">
          <defs>
            <linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">
              <stop stop-color="#EAF4FF"/>
              <stop offset="1" stop-color="#DDF2E8"/>
            </linearGradient>
          </defs>
          <rect width="420" height="280" rx="28" fill="url(#bg)"/>
          <rect x="34" y="34" width="352" height="212" rx="20" fill="#FFFFFF" fill-opacity="0.72" stroke="#B9D9F3"/>
          <text x="210" y="126" text-anchor="middle" font-size="20" font-family="Avenir Next, PingFang SC, sans-serif" fill="#2D9CDB">Parse Result</text>
          <text x="210" y="168" text-anchor="middle" font-size="34" font-weight="700" font-family="Avenir Next, PingFang SC, sans-serif" fill="#1F365A">\(safeLabel)</text>
        </svg>
        """

        guard let data = svg.data(using: .utf8) else {
            return nil
        }
        return (data, "image/svg+xml; charset=utf-8")
    }
}
