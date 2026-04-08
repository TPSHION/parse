import Foundation

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3"
    case wav = "WAV"
    case aac = "AAC"
    case m4a = "M4A"
    case flac = "FLAC"
    
    var id: String { self.rawValue }
    
    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "mp3":
            self = .mp3
        case "wav":
            self = .wav
        case "aac":
            self = .aac
        case "m4a":
            self = .m4a
        case "flac":
            self = .flac
        default:
            return nil
        }
    }
    
    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .aac: return "aac"
        case .m4a: return "m4a"
        case .flac: return "flac"
        }
    }
    
    var iconName: String {
        switch self {
        case .mp3, .m4a: return "music.note"
        case .wav, .flac: return "waveform"
        case .aac: return "music.mic"
        }
    }
}
