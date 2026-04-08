import SwiftUI

struct ImageLinkImportSheet: View {
    let resolver: (String) async throws -> RemoteImageImportPreview
    let onResolved: (RemoteImageImportPreview) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var errorMessage: String?
    @State private var isResolving = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输入图片链接")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("支持公开可访问的图片直链。确认后会先下载并识别真实格式，只有你确认导入后才会加入转换列表。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        if urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("请输入图片链接地址")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $urlText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                    }
                    .frame(minHeight: 140, alignment: .topLeading)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit {
                            resolveLink()
                        }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.accentRed)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    Button(action: resolveLink) {
                        HStack(spacing: 8) {
                            if isResolving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            
                            Text(isResolving ? "识别中" : "下载并识别")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canSubmit ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .disabled(!canSubmit || isResolving)
                }
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("链接导入")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func resolveLink() {
        guard canSubmit, !isResolving else { return }
        
        errorMessage = nil
        isResolving = true
        
        Task {
            do {
                let preview = try await resolver(urlText)
                await MainActor.run {
                    onResolved(preview)
                    isResolving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isResolving = false
                }
            }
        }
    }
}
