import SwiftUI
import UIKit

struct EbookLibraryView: View {
    @State private var items: [EbookLibraryItem] = []
    @State private var isImporting = false
    @State private var isDownloadSheetPresented = false
    @State private var isImportPickerPresented = false
    @State private var isFormatConversionPresented = false
    @State private var selectedReaderItem: EbookLibraryItem?
    @State private var pendingDeletion: EbookLibraryItem?
    @State private var showAlert = false
    @State private var alertMessage: String?

    private let importTypes = EbookConverterViewModel.supportedContentTypes
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    EbookLibraryHeader(
                        onImport: { isImportPickerPresented = true },
                        onConvert: { isFormatConversionPresented = true },
                        onDownload: { isDownloadSheetPresented = true }
                    )

                    if items.isEmpty {
                        EbookShelfEmptyState()
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(items) { item in
                                EbookShelfCard(
                                    item: item,
                                    onRead: { openReader(for: item) },
                                    onDelete: { pendingDeletion = item }
                                )
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }

            if isImporting {
                loadingOverlay
            }
        }
        .navigationTitle(AppLocalizer.localized("电子书"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear(perform: reloadLibrary)
        .fileImporter(
            isPresented: $isImportPickerPresented,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            importBooks(from: result)
        }
        .sheet(isPresented: $isDownloadSheetPresented) {
            EbookDownloadSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        .navigationDestination(item: $selectedReaderItem) { item in
            EPUBReadiumReaderView(item: item)
        }
        .navigationDestination(isPresented: $isFormatConversionPresented) {
            EbookConverterView()
        }
        .alert(AppLocalizer.localized("删除电子书"), isPresented: .constant(pendingDeletion != nil), presenting: pendingDeletion) { item in
            Button(AppLocalizer.localized("取消"), role: .cancel) {
                pendingDeletion = nil
            }
            Button(AppLocalizer.localized("删除"), role: .destructive) {
                remove(item)
            }
        } message: { item in
            Text(AppLocalizer.formatted("确认从书架移除 %@？", item.title))
        }
        .alert(AppLocalizer.localized("电子书"), isPresented: $showAlert) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)

                Text(AppLocalizer.localized("正在处理电子书..."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(AppColors.cardBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func reloadLibrary() {
        items = EbookLibraryService.loadItems()

        Task {
            do {
                let refreshedItems = try await Task.detached(priority: .utility) {
                    try EbookLibraryService.refreshCoverAssetsIfNeeded()
                }.value

                await MainActor.run {
                    items = refreshedItems
                }
            } catch {
                // Keep the bookshelf available even if cover repair fails.
            }
        }
    }

    private func importBooks(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true

            Task {
                do {
                    let updatedItems = try await Task.detached(priority: .userInitiated) {
                        try EbookLibraryService.importItems(from: urls)
                    }.value
                    await MainActor.run {
                        items = updatedItems
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }

                await MainActor.run {
                    isImporting = false
                }
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func remove(_ item: EbookLibraryItem) {
        do {
            items = try EbookLibraryService.remove(item)
            pendingDeletion = nil
        } catch {
            pendingDeletion = nil
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func openReader(for item: EbookLibraryItem) {
        guard item.sourceFormat == .epub else {
            alertMessage = AppLocalizer.localized("TXT 阅读功能即将支持")
            showAlert = true
            return
        }

        selectedReaderItem = item
    }
}

private struct EbookLibraryHeader: View {
    let onImport: () -> Void
    let onConvert: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Parse Bookshelf")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.accentPurple)
                    .textCase(.uppercase)
                    .tracking(1.4)

                Text(AppLocalizer.localized("电子书"))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("在一个页面里管理已导入电子书，快速阅读或进入格式转换。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                ActionPillButton(icon: "square.and.arrow.down.fill", title: AppLocalizer.localized("导入"), filled: true, accent: AppColors.accentPurple, action: onImport)
                ActionPillButton(icon: "arrow.triangle.2.circlepath.doc.on.clipboard", title: AppLocalizer.localized("格式转换"), filled: false, accent: AppColors.accentBlue, action: onConvert)
                ActionPillButton(icon: "arrow.down.circle.fill", title: AppLocalizer.localized("下载"), filled: false, accent: AppColors.accentGreen, action: onDownload)
            }
        }
    }
}

private struct ActionPillButton: View {
    let icon: String
    let title: String
    let filled: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(filled ? .white : .white.opacity(0.9))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled ? accent.opacity(0.95) : AppColors.cardBackground.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(filled ? Color.clear : .white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EbookShelfEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBackground, AppColors.secondaryBackground.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(AppColors.accentPurple)

                        Text(AppLocalizer.localized("书架还是空的"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(AppLocalizer.localized("先导入 EPUB 或 TXT 文件，就可以在这里统一管理和阅读。"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
        }
    }
}

private struct EbookShelfCard: View {
    let item: EbookLibraryItem
    let onRead: () -> Void
    let onDelete: () -> Void

    private var coverImage: UIImage? {
        guard
            let coverURL = EbookLibraryService.coverURL(for: item),
            let image = UIImage(contentsOfFile: coverURL.path)
        else {
            return nil
        }
        return image
    }

    private var fallbackCoverTitle: String {
        let compact = item.title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? AppLocalizer.localized("电子书") : compact
    }

    var body: some View {
        Button(action: onRead) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    coverBackground
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.72, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        )

                    Menu {
                        Button(AppLocalizer.localized("阅读"), action: onRead)
                        Button(AppLocalizer.localized("删除"), role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverBackground: some View {
        if let coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardGradient)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                        Text(fallbackCoverTitle)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                }
        }
    }

    private var cardGradient: LinearGradient {
        let colors: [Color]
        switch item.sourceFormat {
        case .epub:
            colors = [AppColors.accentPurple.opacity(0.95), AppColors.accentBlue.opacity(0.72)]
        case .txt:
            colors = [AppColors.accentTeal.opacity(0.92), AppColors.accentBlue.opacity(0.58)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct EbookDownloadSheet: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.localized("下载电子书"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("从合法公版站点获取 EPUB 资源，再导入到书架中。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                DownloadSourceRow(
                    title: "Project Gutenberg",
                    detail: AppLocalizer.localized("免费公版书资源，适合下载 EPUB 测试样本。"),
                    action: { openURL(URL(string: "https://www.gutenberg.org/")!) }
                )
                DownloadSourceRow(
                    title: "Standard Ebooks",
                    detail: AppLocalizer.localized("排版更精致的公版 EPUB 资源。"),
                    action: { openURL(URL(string: "https://standardebooks.org/ebooks")!) }
                )
                DownloadSourceRow(
                    title: "Open Library",
                    detail: AppLocalizer.localized("可浏览和借阅部分公开电子书资源。"),
                    action: { openURL(URL(string: "https://openlibrary.org/")!) }
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 10)
        }
    }
}

private struct DownloadSourceRow: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.secondaryBackground)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.accentBlue)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        EbookLibraryView()
    }
}
