import Combine
import Foundation

@MainActor
final class AudioSMBImportViewModel: ObservableObject {
    @Published var connection = SMBAudioConnectionDetails() {
        didSet {
            handleConnectionChange(from: oldValue, to: connection)
        }
    }
    @Published var shares: [SMBShareItem] = []
    @Published var audioFiles: [SMBRemoteAudioFile] = []
    @Published var selectedFileIDs = Set<String>()
    @Published var isConnecting = false
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var hasBrowsed = false
    
    private let service: SMBAudioImportService

    init(service: SMBAudioImportService? = nil) {
        self.service = service ?? SMBAudioImportService()
    }

    var canConnect: Bool {
        connection.canConnectToServer && !isConnecting && !isLoading && !isImporting
    }
    
    var canBrowse: Bool {
        isConnected && !connection.trimmedShareName.isEmpty && !isConnecting && !isLoading && !isImporting
    }
    
    var canImport: Bool {
        isConnected && !selectedAudioFiles.isEmpty && !isConnecting && !isLoading && !isImporting
    }
    
    var selectedAudioFiles: [SMBRemoteAudioFile] {
        audioFiles.filter { selectedFileIDs.contains($0.id) }
    }

    var selectedShare: SMBShareItem? {
        shares.first { $0.name == connection.trimmedShareName }
    }

    func connect() {
        guard canConnect else { return }

        errorMessage = nil
        isConnecting = true

        let connection = self.connection
        Task {
            do {
                let fetchedShares = try await service.listShares(connection: connection)
                await MainActor.run {
                    self.shares = fetchedShares
                    if let firstShare = fetchedShares.first {
                        self.connection.shareName = firstShare.name
                    } else {
                        self.connection.shareName = ""
                    }
                    isConnected = true
                    isConnecting = false
                    errorMessage = fetchedShares.isEmpty ? SMBAudioImportError.noSharesFound.localizedDescription : nil
                }
            } catch {
                await MainActor.run {
                    isConnected = false
                    isConnecting = false
                    self.shares = []
                    self.connection.shareName = ""
                    audioFiles = []
                    selectedFileIDs.removeAll()
                    hasBrowsed = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectShare(_ shareName: String) {
        guard connection.shareName != shareName else { return }
        connection.shareName = shareName
    }
    
    func browse() {
        guard canBrowse else { return }
        
        errorMessage = nil
        hasBrowsed = true
        isLoading = true
        selectedFileIDs.removeAll()
        
        let connection = self.connection
        Task {
            do {
                let files = try await service.listAudioFiles(connection: connection)
                await MainActor.run {
                    audioFiles = files
                    errorMessage = files.isEmpty ? SMBAudioImportError.noAudioFilesFound.localizedDescription : nil
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    audioFiles = []
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    func toggleSelection(for fileID: String) {
        if selectedFileIDs.contains(fileID) {
            selectedFileIDs.remove(fileID)
        } else {
            selectedFileIDs.insert(fileID)
        }
    }
    
    func importSelectedFiles() async throws -> [ImportedAudioFile] {
        guard canImport else { return [] }
        
        errorMessage = nil
        isImporting = true
        defer { isImporting = false }
        
        return try await service.downloadAudioFiles(selectedAudioFiles, connection: connection)
    }

    private func handleConnectionChange(from oldValue: SMBAudioConnectionDetails, to newValue: SMBAudioConnectionDetails) {
        let serverChanged = oldValue.serverIdentity != newValue.serverIdentity
        let shareChanged = oldValue.trimmedShareName != newValue.trimmedShareName
        let directoryChanged = oldValue.normalizedDirectoryPath != newValue.normalizedDirectoryPath

        guard serverChanged || shareChanged || directoryChanged else { return }

        errorMessage = nil
        audioFiles = []
        selectedFileIDs.removeAll()
        hasBrowsed = false

        if serverChanged {
            isConnected = false
            shares = []
            if !newValue.trimmedShareName.isEmpty {
                connection.shareName = ""
            }
        }
    }
}
