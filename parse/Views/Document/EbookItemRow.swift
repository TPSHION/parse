import SwiftUI

struct EbookItemRow: View {
    let item: EbookItem
    let onFormatChange: (EbookTargetFormat) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.secondaryBackground)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColors.accentPurple)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.extractedTitle ?? item.originalName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(byteCountText(item.fileSize))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    Text(item.sourceFormat.shortLabel)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.secondaryBackground)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))

                    Picker("Format", selection: Binding(
                        get: { item.targetFormat },
                        set: { onFormatChange($0) }
                    )) {
                        ForEach(EbookTargetFormat.allCases) { format in
                            Text(format.shortLabel).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.accentPurple)
                    .font(.system(size: 10, weight: .bold))
                    .fixedSize()
                    .disabled(isLocked)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                statusView

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textSecondary)
        case .converting(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(AppColors.accentPurple)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.accentPurple)
            }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.accentGreen)
        case .failed(let error):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.accentRed)
                .help(error)
        }
    }

    private var isLocked: Bool {
        if case .converting = item.status {
            return true
        }
        return false
    }

    private func byteCountText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
