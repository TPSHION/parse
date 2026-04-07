import SwiftUI

struct VideoItemRow: View {
    let item: VideoItem
    let onFormatChange: (VideoFormat) -> Void
    let onDelete: () -> Void
    
    @State private var showFailedAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            thumbnailView
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.originalName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 原始格式标签
                    Text(item.originalFormat)
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
                    
                    // 目标格式选择
                    Picker("Format", selection: Binding(
                        get: { item.targetFormat },
                        set: { onFormatChange($0) }
                    )) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.accentBlue)
                    .font(.system(size: 10, weight: .bold))
                    .fixedSize()
                }
                
                if case .converting = item.status {
                    ProgressView(value: item.conversionProgress)
                        .tint(AppColors.accentBlue)
                        .frame(height: 4)
                        .padding(.top, 4)
                }
            }
            
            Spacer(minLength: 8)
            
            HStack(spacing: 14) {
                statusView(for: item.status)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .alert("转换失败", isPresented: $showFailedAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            if case .failed(let msg) = item.status {
                Text(msg)
            }
        }
    }
    
    private var thumbnailView: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(AppColors.secondaryBackground)
                        .overlay {
                            Image(systemName: "video.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.textSecondary)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(durationText(item.duration))
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
            .padding(6)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func statusView(for status: VideoItem.ConversionStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textSecondary)
        case .converting:
            ProgressView()
                .tint(AppColors.accentBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.accentGreen)
        case .failed:
            Button(action: {
                showFailedAlert = true
            }) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(AppColors.accentRed)
            }
            .buttonStyle(.plain)
        }
    }

    private func durationText(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "--:--" }
        let totalSeconds = Int(value.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
