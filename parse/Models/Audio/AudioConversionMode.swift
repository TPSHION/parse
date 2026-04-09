import Foundation

enum AudioConversionMode: String, CaseIterable, Identifiable {
    case quality = "质量优先"
    case speed = "速度优先"
    
    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .quality:
            return AppLocalizer.localized("质量优先")
        case .speed:
            return AppLocalizer.localized("速度优先")
        }
    }
}
