import Foundation
import ReadiumShared

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
    private static let locatorPrefix = "ebook.reader.locator."
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

    static func loadLocator(for itemID: UUID) -> Locator? {
        guard let jsonString = UserDefaults.standard.string(forKey: locatorPrefix + itemID.uuidString) else {
            return nil
        }
        return try? Locator(jsonString: jsonString)
    }

    static func saveLocator(_ locator: Locator, for itemID: UUID) {
        UserDefaults.standard.set(locator.jsonString, forKey: locatorPrefix + itemID.uuidString)
    }
}
