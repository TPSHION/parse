import Foundation
import SwiftUI

struct RemoteImageImportPreview: Identifiable, Equatable {
    static let largeFileThresholdInBytes: Int64 = 10 * 1024 * 1024

    let id = UUID()
    let sourceURL: URL
    let localFileURL: URL
    let previewImage: UIImage?
    let displayFilename: String
    let displayName: String
    let detectedFormat: String
    let mimeType: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSizeInBytes: Int64
    
    var dimensionsText: String {
        guard pixelWidth > 0, pixelHeight > 0 else { return AppLocalizer.localized("未知") }
        return "\(pixelWidth) × \(pixelHeight)"
    }
    
    var fileSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeInBytes)
    }

    var requiresLargeFileConfirmation: Bool {
        fileSizeInBytes >= Self.largeFileThresholdInBytes
    }
    
    static func == (lhs: RemoteImageImportPreview, rhs: RemoteImageImportPreview) -> Bool {
        lhs.id == rhs.id
    }
}
