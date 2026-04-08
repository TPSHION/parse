import Foundation

struct SMBRemoteAudioFile: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let path: String
    let fileSize: Int64
    let format: AudioFormat
    
    init(name: String, path: String, fileSize: Int64, format: AudioFormat) {
        self.id = path
        self.name = name
        self.path = path
        self.fileSize = fileSize
        self.format = format
    }
    
    var fileSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
