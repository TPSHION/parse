import Foundation
import UniformTypeIdentifiers

enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case mov = "MOV"
    case gif = "GIF"
    case avi = "AVI"
    case mkv = "MKV"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .gif: return "gif"
        case .avi: return "avi"
        case .mkv: return "mkv"
        }
    }
}
