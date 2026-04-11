import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    nonisolated static let storageKey = "selected_app_language"
    nonisolated static let automaticValue = ""

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

    nonisolated static func resolveStored(from rawValue: String?) -> AppLanguage? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return AppLanguage(rawValue: rawValue)
    }

    nonisolated static var systemPreferred: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let normalizedIdentifier = identifier.lowercased()
            if normalizedIdentifier.hasPrefix("zh") {
                return .simplifiedChinese
            }
            if normalizedIdentifier.hasPrefix("en") {
                return .english
            }
        }
        return .english
    }

    nonisolated static func effective(from rawValue: String?) -> AppLanguage {
        resolveStored(from: rawValue) ?? systemPreferred
    }
}

enum AppLocalizer {
    nonisolated static var currentLanguage: AppLanguage {
        AppLanguage.effective(from: UserDefaults.standard.string(forKey: AppLanguage.storageKey))
    }

    nonisolated static func localized(_ key: String, language: AppLanguage) -> String {
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

    nonisolated static func localized(_ key: String) -> String {
        localized(key, language: currentLanguage)
    }

    nonisolated static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: currentLanguage.locale, arguments: arguments)
    }
}
