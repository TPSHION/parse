import Foundation
import UniformTypeIdentifiers

enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case mov = "MOV"
    case ts = "TS"
    case gif = "GIF"
    case avi = "AVI"
    case mkv = "MKV"
    
    var id: String { rawValue }

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "mp4":
            self = .mp4
        case "mov":
            self = .mov
        case "ts":
            self = .ts
        case "gif":
            self = .gif
        case "avi":
            self = .avi
        case "mkv":
            self = .mkv
        default:
            return nil
        }
    }
    
    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .ts: return "ts"
        case .gif: return "gif"
        case .avi: return "avi"
        case .mkv: return "mkv"
        }
    }
}
