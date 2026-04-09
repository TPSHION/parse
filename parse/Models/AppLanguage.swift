import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    nonisolated static let storageKey = "selected_app_language"

    nonisolated var id: String { rawValue }

    nonisolated var locale: Locale {
        Locale(identifier: rawValue)
    }

    nonisolated var displayName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    nonisolated var shortLabel: String {
        switch self {
        case .simplifiedChinese:
            return "中"
        case .english:
            return "EN"
        }
    }

    nonisolated static func resolve(from rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .simplifiedChinese
    }
}

enum AppLocalizer {
    nonisolated static var currentLanguage: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            ?? AppLanguage.simplifiedChinese.rawValue
        return AppLanguage.resolve(from: rawValue)
    }

    nonisolated static func localized(_ key: String) -> String {
        let language = currentLanguage

        guard language != .simplifiedChinese else {
            return key
        }

        guard
            let bundlePath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    nonisolated static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: currentLanguage.locale, arguments: arguments)
    }
}
