import Foundation

enum AudioConversionMode: String, CaseIterable, Identifiable {
    case quality = "质量优先"
    case speed = "速度优先"
    
    var id: String { rawValue }
}
