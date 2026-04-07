import Foundation
import UniformTypeIdentifiers

enum ImageFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case tiff = "TIFF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
    
    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }
}
