import SwiftUI

enum AppColors {
    /// 页面大背景色 (Very Dark Slate)
    static let background = Color(hex: "#0F172A")
    /// 卡片/列表项背景色 (Dark Slate)
    static let cardBackground = Color(hex: "#1E293B")
    /// 边框或次级卡片背景 (Lighter Slate)
    static let secondaryBackground = Color(hex: "#334155")
    
    /// 主要文字颜色 (Light Slate)
    static let textPrimary = Color(hex: "#F8FAFC")
    /// 次要文字颜色
    static let textSecondary = Color(hex: "#94A3B8")
    
    /// CTA / 成功状态强调色 (Green)
    static let accentGreen = Color(hex: "#22C55E")
    /// 默认可交互元素强调色 (Blue)
    static let accentBlue = Color(hex: "#3B82F6")
    /// 失败/警告状态色 (Red)
    static let accentRed = Color(hex: "#EF4444")
    /// 文档相关强调色 (Purple)
    static let accentPurple = Color(hex: "#A855F7")
    /// 音频相关强调色 (Orange/Yellow)
    static let accentOrange = Color(hex: "#F59E0B")
    /// 数据压缩相关强调色 (Teal)
    static let accentTeal = Color(hex: "#14B8A6")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
