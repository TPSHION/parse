import Foundation

struct SMBAudioConnectionDetails: Equatable {
    var serverAddress = ""
    var shareName = ""
    var directoryPath = "/"
    var username = ""
    var password = ""
    var domain = ""
    
    var trimmedServerAddress: String {
        serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedShareName: String {
        shareName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var normalizedDirectoryPath: String {
        var path = directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            return "/"
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
    
    var effectiveUsername: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "guest" : trimmed
    }

    var trimmedDomain: String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var serverIdentity: SMBServerIdentity {
        SMBServerIdentity(
            serverAddress: trimmedServerAddress,
            username: effectiveUsername,
            password: password,
            domain: trimmedDomain
        )
    }

    var shareIdentity: SMBShareIdentity {
        SMBShareIdentity(
            serverIdentity: serverIdentity,
            shareName: trimmedShareName
        )
    }
    
    var canConnectToServer: Bool {
        !trimmedServerAddress.isEmpty
    }
}

struct SMBServerIdentity: Equatable {
    let serverAddress: String
    let username: String
    let password: String
    let domain: String
}

struct SMBShareIdentity: Equatable {
    let serverIdentity: SMBServerIdentity
    let shareName: String
}

struct SMBShareItem: Identifiable, Equatable {
    let name: String
    let comment: String

    var id: String { name }

    var displayTitle: String {
        comment.isEmpty ? name : "\(name) · \(comment)"
    }
}
