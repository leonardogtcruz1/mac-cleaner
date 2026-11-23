import Foundation

public enum AppLanguage: String, Sendable {
    case pt
    case en
}

public enum L10n {
    nonisolated(unsafe) public static var language: AppLanguage = .pt

    public static var isEnglish: Bool {
        language == .en
    }

    public static var locale: Locale {
        Locale(identifier: isEnglish ? "en_US" : "pt_BR")
    }

    public static func t(_ pt: String, _ en: String) -> String {
        isEnglish ? en : pt
    }
}
