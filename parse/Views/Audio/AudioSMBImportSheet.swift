import SwiftUI

struct AudioSMBImportSheet: View {
    let onImport: ([ImportedAudioFile]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AudioSMBImportViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        connectionCard
                        filesCard
                    }
                    .padding(.top, 4)
                }
                
                actionBar
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("局域网导入")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }
    
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Windows SMB 共享")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(AppColors.textPrimary)
            
            Text("先连接服务器，选择共享后再读取目录并导入音频文件。")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            VStack(spacing: 12) {
                fieldRow(title: "服务器", text: $viewModel.connection.serverAddress, placeholder: "例如 192.168.1.20 或 DESKTOP-ABC")
                fieldRow(title: "账号", text: $viewModel.connection.username, placeholder: "留空则使用 guest")
                secureFieldRow(title: "密码", text: $viewModel.connection.password, placeholder: "如有密码请填写")
                fieldRow(title: "域", text: $viewModel.connection.domain, placeholder: "可选")
            }
            
            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.isConnected ? AppColors.accentGreen : AppColors.textSecondary.opacity(0.35))
                    .frame(width: 10, height: 10)

                Text(viewModel.isConnected ? "服务器已连接" : "尚未连接服务器")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(viewModel.isConnected ? AppColors.accentGreen : AppColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 2)

            Button(action: viewModel.connect) {
                HStack(spacing: 8) {
                    if viewModel.isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: viewModel.isConnected ? "checkmark.shield.fill" : "network")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    
                    Text(viewModel.isConnecting ? "连接中" : (viewModel.isConnected ? "重新连接服务器" : "连接服务器"))
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(viewModel.canConnect ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(!viewModel.canConnect)

            if viewModel.isConnected {
                sharePicker
                fieldRow(title: "目录", text: $viewModel.connection.directoryPath, placeholder: "默认 /")
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.accentRed)
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var sharePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("共享")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)

            Menu {
                ForEach(viewModel.shares) { share in
                    Button {
                        viewModel.selectShare(share.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(share.name)
                            if !share.comment.isEmpty {
                                Text(share.comment)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accentOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedShare?.name ?? "请选择共享")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(viewModel.selectedShare?.comment.isEmpty == false ? viewModel.selectedShare?.comment ?? "" : "连接服务器后自动读取共享列表")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(AppColors.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(viewModel.shares.isEmpty)
        }
    }
    
    private var filesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("可导入文件")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button(action: viewModel.browse) {
                    HStack(spacing: 6) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(AppColors.accentOrange)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Text(viewModel.isLoading ? "读取中" : "读取目录")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(viewModel.canBrowse ? AppColors.accentOrange : AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(AppColors.secondaryBackground.opacity(0.35))
                    .clipShape(Capsule())
                }
                .disabled(!viewModel.canBrowse)

                if !viewModel.audioFiles.isEmpty {
                    Text("已选 \(viewModel.selectedFileIDs.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.accentOrange)
                }
            }
            
            if viewModel.audioFiles.isEmpty {
                Text(emptyFilesMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppColors.secondaryBackground.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.audioFiles) { file in
                        Button(action: {
                            viewModel.toggleSelection(for: file.id)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.selectedFileIDs.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(viewModel.selectedFileIDs.contains(file.id) ? AppColors.accentOrange : AppColors.textSecondary.opacity(0.7))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(2)
                                    
                                    Text("\(file.format.rawValue) · \(file.fileSizeText)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                            }
                            .padding(14)
                            .background(AppColors.secondaryBackground.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    
    private var actionBar: some View {
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
            
            Button(action: importSelectedFiles) {
                HStack(spacing: 8) {
                    if viewModel.isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(viewModel.isImporting ? "导入中" : "导入所选")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.canImport ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(!viewModel.canImport)
        }
    }
    
    private func fieldRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(AppColors.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private func secureFieldRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
            SecureField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(AppColors.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    
    private func importSelectedFiles() {
        Task {
            do {
                let files = try await viewModel.importSelectedFiles()
                await MainActor.run {
                    onImport(files)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var emptyFilesMessage: String {
        if !viewModel.isConnected {
            return "请先连接服务器。"
        }
        if viewModel.connection.trimmedShareName.isEmpty {
            return "请选择一个共享后再读取目录。"
        }
        if viewModel.hasBrowsed {
            return "当前目录没有可导入的音频文件。"
        }
        return "选择共享后，点击“读取目录”查看可导入的音频文件。"
    }
}
