import SwiftUI
import UIKit

struct ConvertedFileSaveSelectionItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let badgeText: String
    let previewImage: UIImage?
    let iconName: String
    let accentColor: Color
    let fileURL: URL
    let supportsPhotoLibrarySave: Bool
}

struct ConvertedFileSaveSelectionSheet: View {
    let items: [ConvertedFileSaveSelectionItem]
    @Binding var selectedItemIDs: Set<UUID>
    let onSaveToAlbum: (() -> Void)?
    let onSaveToFile: () -> Void
    let onOpenTransferGuide: (() -> Void)?
    @State private var isShareSheetPresented = false

    private var selectedCount: Int {
        items.filter { selectedItemIDs.contains($0.id) }.count
    }

    private var selectedShareableURLs: [URL] {
        items.compactMap { item in
            guard selectedItemIDs.contains(item.id) else { return nil }
            return item.fileURL
        }
    }

    private var selectedPhotoLibraryEligibleCount: Int {
        items.filter { selectedItemIDs.contains($0.id) && $0.supportsPhotoLibrarySave }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            selectionToolbar
            itemList
            actionButtons
        }
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityShareSheet(items: selectedShareableURLs)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.localized("选择要保存的资源"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Text(AppLocalizer.localized("可先勾选要导出的转换结果，再选择分享、相册、文件夹或网页下载。"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionToolbar: some View {
        HStack {
            Text(AppLocalizer.formatted("已选 %lld/%lld", selectedCount, items.count))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button(AppLocalizer.localized("全选")) {
                selectedItemIDs = Set(items.map(\.id))
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppColors.accentBlue)

            Button(AppLocalizer.localized("清空")) {
                selectedItemIDs.removeAll()
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppColors.accentRed)
        }
    }

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    ConvertedFileSaveSelectionRow(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        onToggle: {
                            toggleSelection(for: item.id)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actionButtons: some View {
        let rows = stride(from: 0, to: actionButtonConfigs.count, by: 2).map {
            Array(actionButtonConfigs[$0..<min($0 + 2, actionButtonConfigs.count)])
        }

        return VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, config in
                        Button(action: config.action) {
                            actionButton(
                                icon: config.icon,
                                title: config.title,
                                accent: config.accent,
                                foreground: config.foreground
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(config.isDisabled)
                    }

                    if row.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                }
            }
        }
    }

    private var actionButtonConfigs: [ConvertedFileActionButtonConfig] {
        var configs: [ConvertedFileActionButtonConfig] = [
            ConvertedFileActionButtonConfig(
                icon: "square.and.arrow.up",
                title: AppLocalizer.localized("分享"),
                accent: selectedShareableURLs.isEmpty ? AppColors.secondaryBackground.opacity(0.5) : AppColors.accentBlue,
                foreground: selectedShareableURLs.isEmpty ? AppColors.textSecondary.opacity(0.5) : .white,
                isDisabled: selectedShareableURLs.isEmpty,
                action: { isShareSheetPresented = true }
            )
        ]

        if let onSaveToAlbum {
            configs.append(
                ConvertedFileActionButtonConfig(
                    icon: "photo.on.rectangle.angled",
                    title: AppLocalizer.localized("相册"),
                    accent: selectedPhotoLibraryEligibleCount > 0 ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5),
                    foreground: selectedPhotoLibraryEligibleCount > 0 ? .white : AppColors.textSecondary.opacity(0.5),
                    isDisabled: selectedPhotoLibraryEligibleCount == 0,
                    action: onSaveToAlbum
                )
            )
        }

        configs.append(
            ConvertedFileActionButtonConfig(
                icon: "folder",
                title: AppLocalizer.localized("文件夹"),
                accent: selectedCount > 0 ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5),
                foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5),
                isDisabled: selectedCount == 0,
                action: onSaveToFile
            )
        )

        if let onOpenTransferGuide {
            configs.append(
                ConvertedFileActionButtonConfig(
                    icon: "wifi",
                    title: AppLocalizer.localized("传输"),
                    accent: selectedCount > 0 ? AppColors.accentPurple : AppColors.secondaryBackground.opacity(0.5),
                    foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5),
                    isDisabled: selectedCount == 0,
                    action: onOpenTransferGuide
                )
            )
        }

        return configs
    }

    private func actionButton(icon: String, title: String, accent: Color, foreground: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
}

private struct ConvertedFileActionButtonConfig {
    let icon: String
    let title: String
    let accent: Color
    let foreground: Color
    let isDisabled: Bool
    let action: () -> Void
}

private struct ConvertedFileSaveSelectionRow: View {
    let item: ConvertedFileSaveSelectionItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.accentBlue : AppColors.textSecondary.opacity(0.6))

                preview

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Text(item.badgeText)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.accentColor.opacity(0.18))
                            .foregroundColor(item.accentColor)
                            .clipShape(Capsule())
                    }

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColors.accentBlue.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let previewImage = item.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.accentColor.opacity(0.16))
                    .overlay {
                        Image(systemName: item.iconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(item.accentColor)
                    }
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
