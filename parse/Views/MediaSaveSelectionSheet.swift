import SwiftUI

struct MediaSaveSelectionSheet: View {
    let items: [MediaCompressionItem]
    @Binding var selectedItemIDs: Set<UUID>
    let onSaveToAlbum: () -> Void
    let onSaveToFile: () -> Void
    let onOpenTransferGuide: () -> Void

    private var selectedCount: Int {
        items.filter { selectedItemIDs.contains($0.id) }.count
    }

    private var selectedShareableURLs: [URL] {
        items.compactMap { item in
            guard selectedItemIDs.contains(item.id) else { return nil }
            return item.outputURL
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.localized("选择要保存的资源"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Text(AppLocalizer.localized("可先勾选要导出的压缩结果，再选择分享、相册、文件夹或网页下载。相册仅支持图片、MP4、MOV 和 GIF。"))
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
                    MediaSaveSelectionRow(
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
        VStack(spacing: 12) {
            Group {
                if selectedShareableURLs.isEmpty {
                    actionButton(
                        icon: "square.and.arrow.up",
                        title: AppLocalizer.localized("分享文件"),
                        accent: AppColors.secondaryBackground.opacity(0.5),
                        foreground: AppColors.textSecondary.opacity(0.5)
                    )
                } else {
                    ShareLink(items: selectedShareableURLs) {
                        actionButton(
                            icon: "square.and.arrow.up",
                            title: AppLocalizer.localized("分享文件"),
                            accent: AppColors.accentBlue,
                            foreground: .white
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button(action: onSaveToAlbum) {
                    actionButton(
                        icon: "photo.on.rectangle.angled",
                        title: AppLocalizer.localized("保存到相册"),
                        accent: selectedPhotoLibraryEligibleCount > 0 ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5),
                        foreground: selectedPhotoLibraryEligibleCount > 0 ? .white : AppColors.textSecondary.opacity(0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedPhotoLibraryEligibleCount == 0)

                Button(action: onSaveToFile) {
                    actionButton(
                        icon: "folder",
                        title: AppLocalizer.localized("保存为文件"),
                        accent: selectedCount > 0 ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5),
                        foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)
            }

            Button(action: onOpenTransferGuide) {
                actionButton(
                    icon: "wifi",
                    title: AppLocalizer.localized("网页下载"),
                    accent: selectedCount > 0 ? AppColors.accentPurple : AppColors.secondaryBackground.opacity(0.5),
                    foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
        }
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

private struct MediaSaveSelectionRow: View {
    let item: MediaCompressionItem
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
                        Text(item.filename)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Text(item.typeLabel)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.18))
                            .foregroundColor(typeColor)
                            .clipShape(Capsule())
                    }

                    Text(item.secondaryDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)

                    if !item.supportsPhotoLibrarySave {
                        Text(AppLocalizer.localized("相册不支持"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.accentRed)
                    }
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
                    .fill(typeColor.opacity(0.16))
                    .overlay {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(typeColor)
                    }
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var typeColor: Color {
        switch item.type {
        case .image:
            return AppColors.accentBlue
        case .video:
            return AppColors.accentGreen
        case .audio:
            return AppColors.accentOrange
        }
    }
}
