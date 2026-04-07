import SwiftUI
import UIKit

struct VideoItem: Identifiable, Equatable {
    let id = UUID()
    let originalURL: URL
    let originalName: String
    let originalFormat: String
    let thumbnail: UIImage?
    let duration: Double
    let fileSizeInBytes: Int64?
    
    var targetFormat: VideoFormat = .mp4
    var status: ConversionStatus = .pending
    
    /// 转换成功后，保存在磁盘上的临时文件 URL
    var convertedFileURL: URL? = nil
    /// FFmpeg 转换进度 0.0 ~ 1.0
    var conversionProgress: Double = 0.0
    
    enum ConversionStatus: Equatable {
        case pending
        case converting
        case success
        case failed(String)
    }
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}
