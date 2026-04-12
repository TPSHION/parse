import Foundation
import UniformTypeIdentifiers

enum EbookSourceFormat: String, CaseIterable, Identifiable, Codable {
    case epub = "EPUB"
    case txt = "TXT"

    nonisolated var id: String { rawValue }

    nonisolated var shortLabel: String { rawValue }

    nonisolated var fileExtension: String {
        switch self {
        case .epub:
            return "epub"
        case .txt:
            return "txt"
        }
    }

    nonisolated var contentType: UTType {
        UTType(filenameExtension: fileExtension) ?? .data
    }

    nonisolated static func resolve(from url: URL) -> EbookSourceFormat? {
        let ext = url.pathExtension.lowercased()
        return Self.allCases.first { $0.fileExtension == ext }
    }
}
