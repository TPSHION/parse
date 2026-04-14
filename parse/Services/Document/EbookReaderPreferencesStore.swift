import Foundation

struct TXTReaderProgress: Codable, Equatable {
    var chapterIndex: Int
    var chapterProgress: Double
}

struct ReaderStyleSettings: Equatable {
    var fontSize: Double
    var letterSpacing: Double
    var lineHeight: Double
    var isScrollEnabled: Bool
    var themeRawValue: String

    static let `default` = ReaderStyleSettings(
        fontSize: 1.0,
        letterSpacing: 0,
        lineHeight: 1.5,
        isScrollEnabled: false,
        themeRawValue: "dark"
    )
}

enum EbookReaderPreferencesStore {
    private static let txtProgressPrefix = "ebook.reader.txtProgress."
    private static let fontSizeKey = "ebook.reader.fontSize"
    private static let letterSpacingKey = "ebook.reader.letterSpacing"
    private static let lineHeightKey = "ebook.reader.lineHeight"
    private static let scrollModeKey = "ebook.reader.scrollMode"
    private static let themeKey = "ebook.reader.theme"

    static func loadStyleSettings() -> ReaderStyleSettings {
        let defaults = UserDefaults.standard
        let fontSize = defaults.object(forKey: fontSizeKey) as? Double ?? ReaderStyleSettings.default.fontSize
        let letterSpacing = defaults.object(forKey: letterSpacingKey) as? Double ?? ReaderStyleSettings.default.letterSpacing
        let lineHeight = defaults.object(forKey: lineHeightKey) as? Double ?? ReaderStyleSettings.default.lineHeight
        let isScrollEnabled = defaults.object(forKey: scrollModeKey) as? Bool ?? ReaderStyleSettings.default.isScrollEnabled
        let themeRawValue = defaults.string(forKey: themeKey) ?? ReaderStyleSettings.default.themeRawValue
        return ReaderStyleSettings(fontSize: fontSize, letterSpacing: letterSpacing, lineHeight: lineHeight, isScrollEnabled: isScrollEnabled, themeRawValue: themeRawValue)
    }

    static func saveStyleSettings(_ settings: ReaderStyleSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.fontSize, forKey: fontSizeKey)
        defaults.set(settings.letterSpacing, forKey: letterSpacingKey)
        defaults.set(settings.lineHeight, forKey: lineHeightKey)
        defaults.set(settings.isScrollEnabled, forKey: scrollModeKey)
        defaults.set(settings.themeRawValue, forKey: themeKey)
    }

    static func loadTXTProgress(for itemID: UUID) -> TXTReaderProgress? {
        guard let data = UserDefaults.standard.data(forKey: txtProgressPrefix + itemID.uuidString) else {
            return nil
        }
        return try? JSONDecoder().decode(TXTReaderProgress.self, from: data)
    }

    static func saveTXTProgress(_ progress: TXTReaderProgress, for itemID: UUID) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: txtProgressPrefix + itemID.uuidString)
    }
}
