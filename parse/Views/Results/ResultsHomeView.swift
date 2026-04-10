import SwiftUI
import UIKit

struct ResultsHomeView: View {
    @State private var sections: [TransferArchivedResultSection] = []
    @State private var pendingDeletion: TransferArchivedResultItem?
    @State private var pendingClearCategory: TransferResultCategory?
    @State private var feedbackMessage: String?

    private var totalCount: Int {
        sections.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    summarySection
                    resultsSection
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("删除结果", isPresented: .constant(pendingDeletion != nil), presenting: pendingDeletion) { item in
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
            Button("删除", role: .destructive) {
                delete(item)
            }
        } message: { item in
            Text("确认删除 \(item.filename) 吗？删除后将不会再出现在历史结果中。")
        }
        .alert("清空结果", isPresented: .constant(pendingClearCategory != nil), presenting: pendingClearCategory) { category in
            Button("取消", role: .cancel) {
                pendingClearCategory = nil
            }
            Button("清空", role: .destructive) {
                clear(category)
            }
        } message: { category in
            Text("确认一键清空\(category.displayTitle)中的全部历史结果吗？此操作不可撤销。")
        }
        .alert("结果提示", isPresented: .constant(feedbackMessage != nil)) {
            Button("确定", role: .cancel) {
                feedbackMessage = nil
            }
        } message: {
            Text(feedbackMessage ?? "")
        }
        .onAppear(perform: reloadResults)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Parse Results")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.accentPurple)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("结果")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(.white)

                    Text("统一查看历史转换与压缩结果，并在这里快速清理不需要的旧文件。")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button(action: reloadResults) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.accentBlue.opacity(0.9))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "总结果数",
                value: "\(totalCount)",
                accent: AppColors.accentPurple
            )

            summaryCard(
                title: "结果分类",
                value: "\(sections.filter { !$0.items.isEmpty }.count)",
                accent: AppColors.accentBlue
            )
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if totalCount == 0 {
                emptyState
            } else {
                ForEach(sections) { section in
                    if !section.items.isEmpty {
                        resultSection(section)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Text("还没有历史结果")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("完成图片、视频、音频转换或压缩后，历史结果会自动出现在这里。")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func resultSection(_ section: TransferArchivedResultSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    pendingClearCategory = section.category
                } label: {
                    Text("清空")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.accentRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.accentRed.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("\(section.count) 项")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(sectionColor(for: section.category))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(sectionColor(for: section.category).opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: 12) {
                ForEach(section.items) { item in
                    resultRow(item)
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func resultRow(_ item: TransferArchivedResultItem) -> some View {
        HStack(spacing: 14) {
            ResultsThumbnailView(
                item: item,
                accentColor: sectionColor(for: item.category),
                fallbackIconName: iconName(for: item.category)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.filename)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text("\(byteCountText(for: item.fileSize)) · \(dateText(for: item.modifiedAt))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                pendingDeletion = item
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.secondaryBackground.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)

            Capsule()
                .fill(accent.opacity(0.85))
                .frame(width: 40, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.cardBackground.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func reloadResults() {
        sections = TransferResultArchiveService.allSections()
    }

    private func delete(_ item: TransferArchivedResultItem) {
        do {
            try TransferResultArchiveService.deleteResult(
                categoryRawValue: item.category.rawValue,
                filename: item.filename
            )
            pendingDeletion = nil
            reloadResults()
        } catch {
            pendingDeletion = nil
            feedbackMessage = error.localizedDescription
        }
    }

    private func clear(_ category: TransferResultCategory) {
        do {
            try TransferResultArchiveService.deleteAllResults(in: category)
            pendingClearCategory = nil
            reloadResults()
        } catch {
            pendingClearCategory = nil
            feedbackMessage = error.localizedDescription
        }
    }

    private func sectionColor(for category: TransferResultCategory) -> Color {
        switch category {
        case .imageConversion:
            return AppColors.accentBlue
        case .videoConversion:
            return AppColors.accentGreen
        case .audioConversion:
            return AppColors.accentOrange
        case .compression:
            return AppColors.accentPurple
        }
    }

    private func iconName(for category: TransferResultCategory) -> String {
        switch category {
        case .imageConversion:
            return "photo.fill"
        case .videoConversion:
            return "video.fill"
        case .audioConversion:
            return "waveform"
        case .compression:
            return "bolt.fill"
        }
    }

    private func byteCountText(for value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func dateText(for date: Date?) -> String {
        guard let date else { return "时间未知" }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ResultsThumbnailView: View {
    let item: TransferArchivedResultItem
    let accentColor: Color
    let fallbackIconName: String

    @State private var thumbnailImage: UIImage?

    var body: some View {
        Group {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(0.16))
                    .overlay {
                        Image(systemName: fallbackIconName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(accentColor)
                    }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: item.id) {
            let previewKind = TransferResultArchiveService.previewKind(for: item.fileURL)
            guard previewKind == .image || previewKind == .video else {
                thumbnailImage = nil
                return
            }
            thumbnailImage = await TransferResultArchiveService.thumbnailImage(for: item.fileURL)
        }
    }
}

#Preview {
    ResultsHomeView()
}
