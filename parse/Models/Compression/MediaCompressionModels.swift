import AVFoundation
import Foundation
import UIKit

enum MediaCompressionType: String, CaseIterable, Identifiable {
    case image = "图片"
    case video = "视频"
    case audio = "音频"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "waveform"
        }
    }
}

enum MediaCompressionLevel: String, CaseIterable, Identifiable {
    case light = "轻度"
    case balanced = "均衡"
    case maximum = "极限"

    var id: String { rawValue }

    var imageCompressionQuality: CGFloat {
        switch self {
        case .light:
            return 0.88
        case .balanced:
            return 0.72
        case .maximum:
            return 0.55
        }
    }

    var imageMaxDimension: CGFloat {
        switch self {
        case .light:
            return 3200
        case .balanced:
            return 2400
        case .maximum:
            return 1600
        }
    }

    var videoBitrate: String {
        switch self {
        case .light:
            return "5M"
        case .balanced:
            return "3M"
        case .maximum:
            return "1800k"
        }
    }

    var videoMaxRate: String {
        switch self {
        case .light:
            return "6M"
        case .balanced:
            return "3500k"
        case .maximum:
            return "2M"
        }
    }

    var videoScaleWidth: Int {
        switch self {
        case .light:
            return 1920
        case .balanced:
            return 1280
        case .maximum:
            return 960
        }
    }

    var videoFPS: Int? {
        switch self {
        case .light:
            return nil
        case .balanced:
            return 30
        case .maximum:
            return 24
        }
    }

    var audioBitrate: String {
        switch self {
        case .light:
            return "192k"
        case .balanced:
            return "128k"
        case .maximum:
            return "96k"
        }
    }

    var audioSampleRate: Int {
        switch self {
        case .light:
            return 48000
        case .balanced:
            return 44100
        case .maximum:
            return 32000
        }
    }

    var flacCompressionLevel: Int {
        switch self {
        case .light:
            return 5
        case .balanced:
            return 8
        case .maximum:
            return 12
        }
    }
}

struct MediaCompressionItem: Identifiable, Equatable {
    let id = UUID()
    let type: MediaCompressionType
    let originalURL: URL
    let filename: String
    let baseName: String
    let originalExtension: String
    let originalSizeInBytes: Int64
    let previewImage: UIImage?
    let duration: Double?
    let pixelSize: CGSize?

    var status: CompressionStatus = .pending
    var outputURL: URL?
    var compressionProgress: Double = 0.0
    var compressedSizeInBytes: Int64?

    enum CompressionStatus: Equatable {
        case pending
        case compressing
        case success
        case failed(String)
    }

    var typeLabel: String {
        type.rawValue
    }

    var originalFormat: String {
        originalExtension.uppercased()
    }

    var originalSizeText: String {
        Self.byteCountFormatter.string(fromByteCount: originalSizeInBytes)
    }

    var compressedSizeText: String? {
        guard let compressedSizeInBytes else { return nil }
        return Self.byteCountFormatter.string(fromByteCount: compressedSizeInBytes)
    }

    var savedBytes: Int64? {
        guard let compressedSizeInBytes else { return nil }
        return max(originalSizeInBytes - compressedSizeInBytes, 0)
    }

    var savedBytesText: String? {
        guard let savedBytes else { return nil }
        return Self.byteCountFormatter.string(fromByteCount: savedBytes)
    }

    var savedPercentageText: String? {
        guard let compressedSizeInBytes, originalSizeInBytes > 0 else { return nil }
        let ratio = Double(originalSizeInBytes - compressedSizeInBytes) / Double(originalSizeInBytes)
        return "\(Int(max(ratio, 0) * 100))%"
    }

    var secondaryDescription: String {
        switch type {
        case .image:
            if let pixelSize {
                return "\(originalFormat) · \(Int(pixelSize.width))×\(Int(pixelSize.height)) · \(originalSizeText)"
            }
            return "\(originalFormat) · \(originalSizeText)"
        case .video:
            if let duration {
                return "\(originalFormat) · \(duration.videoDurationText) · \(originalSizeText)"
            }
            return "\(originalFormat) · \(originalSizeText)"
        case .audio:
            return "\(originalFormat) · \(originalSizeText)"
        }
    }

    nonisolated var supportsPhotoLibrarySave: Bool {
        switch type {
        case .image:
            return true
        case .video:
            switch originalExtension.lowercased() {
            case "mp4", "mov", "gif":
                return true
            default:
                return false
            }
        case .audio:
            return false
        }
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

enum MediaCompressionError: LocalizedError {
    case unsupportedFormat
    case failedToLoadSource
    case failedToCreateDestination
    case noCompressionBenefit
    case sessionUnavailable
    case ffmpegFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "当前文件格式暂不支持压缩"
        case .failedToLoadSource:
            return "读取源文件失败"
        case .failedToCreateDestination:
            return "创建压缩输出文件失败"
        case .noCompressionBenefit:
            return "压缩后体积没有变小，当前格式压缩空间有限"
        case .sessionUnavailable:
            return "压缩会话未能创建"
        case .ffmpegFailed(let message):
            return message
        }
    }
}

struct MediaCompressionPhotoLibrarySaveSummary {
    let savedCount: Int
    let skippedCount: Int
}

enum MediaCompressionSaveError: LocalizedError {
    case photoLibraryAccessDenied
    case unsupportedPhotoLibraryFormat
    case photoLibrarySaveFailed
    case gifPhotoLibrarySaveFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessDenied:
            return "需要相册的“添加照片”权限才能保存压缩结果"
        case .unsupportedPhotoLibraryFormat:
            return "相册仅支持保存图片、MP4、MOV 和 GIF，音频及其他视频格式请使用“保存为文件”"
        case .photoLibrarySaveFailed:
            return "保存到相册失败，请稍后重试"
        case .gifPhotoLibrarySaveFailed:
            return "GIF 保存到相册失败，请确认系统照片支持动画图片导入，或改用“保存为文件”"
        }
    }
}
