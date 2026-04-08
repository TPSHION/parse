import SwiftUI
import UniformTypeIdentifiers

struct AudioItemRow: View {
    let item: AudioItem
    let onFormatChange: (AudioFormat) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Area
            Group {
                Rectangle()
                    .fill(AppColors.secondaryBackground)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accentOrange)
                    }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Info Area
            VStack(alignment: .leading, spacing: 6) {
                Text(item.filename)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 原始格式标签
                    Text(item.originalFormat.isEmpty ? "AUDIO" : item.originalFormat)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.secondaryBackground)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    
                    Picker("Format", selection: Binding(
                        get: { item.targetFormat },
                        set: { onFormatChange($0) }
                    )) {
                        ForEach(AudioFormat.allCases) { format in
                            Text(format.rawValue)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.accentOrange)
                    .font(.system(size: 10, weight: .bold))
                    .fixedSize()
                    .disabled(item.status == .converting)
                }
            }
            
            Spacer()
            
            // Action & Status Area
            HStack(spacing: 12) {
                statusView(for: item.status)
                
                if shouldShowDeleteButton(for: item.status) {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func statusView(for status: AudioItem.ConversionStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textSecondary)
        case .converting:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(AppColors.accentOrange)
                Text("\(Int(item.conversionProgress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.accentOrange)
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
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func shouldShowDeleteButton(for status: AudioItem.ConversionStatus) -> Bool {
        switch status {
        case .pending, .success, .failed:
            return true
        case .converting:
            return false
        }
    }
}
