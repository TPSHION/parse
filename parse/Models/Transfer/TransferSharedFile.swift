import Foundation

struct TransferSharedFile: Identifiable, Hashable {
    let id: URL
    let url: URL
    let filename: String
    let fileSize: Int64
    let modifiedAt: Date?

    init(url: URL, fileSize: Int64, modifiedAt: Date?) {
        self.id = url
        self.url = url
        self.filename = url.lastPathComponent
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var modifiedAtText: String {
        guard let modifiedAt else { return AppLocalizer.localized("刚刚更新") }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.effective(from: UserDefaults.standard.string(forKey: AppLanguage.storageKey)).locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}
