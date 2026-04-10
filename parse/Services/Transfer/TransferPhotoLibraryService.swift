import Foundation
import Photos
import UIKit
import GCDWebServer

enum TransferLibraryKind: String {
    case image
    case video

    var title: String {
        switch self {
        case .image: return "图片"
        case .video: return "视频"
        }
    }

    var mediaType: PHAssetMediaType {
        switch self {
        case .image: return .image
        case .video: return .video
        }
    }
}

enum TransferPhotoLibraryService {
    static func fetchLibraryPayload(for kind: TransferLibraryKind) async -> [String: Any] {
        let status = await ensureReadPermission()
        guard isAuthorized(status) else {
            return [
                "authorization": authorizationText(for: status),
                "items": []
            ]
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", kind.mediaType.rawValue)
        fetchOptions.fetchLimit = 120

        let results = PHAsset.fetchAssets(with: fetchOptions)
        var items: [[String: Any]] = []
        items.reserveCapacity(results.count)

        results.enumerateObjects { asset, _, _ in
            let resource = PHAssetResource.assetResources(for: asset).first
            let filename = resource?.originalFilename ?? kind.title
            var payload: [String: Any] = [
                "id": asset.localIdentifier,
                "name": filename,
                "kind": kind.rawValue,
                "createdAt": asset.creationDate?.ISO8601Format() ?? "",
                "thumbnailURL": "/api/library/thumbnail?id=\(Self.urlEncoded(asset.localIdentifier))&kind=\(kind.rawValue)",
                "downloadURL": "/api/library/download?id=\(Self.urlEncoded(asset.localIdentifier))&kind=\(kind.rawValue)"
            ]

            if kind == .video {
                payload["duration"] = asset.duration
            }

            items.append(payload)
        }

        return [
            "authorization": authorizationText(for: status),
            "items": items
        ]
    }

    static func makeThumbnailResponse(
        identifier: String,
        kind: TransferLibraryKind,
        completion: @escaping (GCDWebServerResponse?) -> Void
    ) {
        Task {
            let status = await ensureReadPermission()
            guard isAuthorized(status) else {
                completion(errorResponse(statusCode: 403, message: "Photo access not granted"))
                return
            }

            guard let asset = asset(with: identifier, kind: kind) else {
                completion(errorResponse(statusCode: 404, message: "Asset not found"))
                return
            }

            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let targetSize = CGSize(width: 560, height: 420)
            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard let image, let data = image.jpegData(compressionQuality: 0.82) else {
                    completion(errorResponse(statusCode: 500, message: "Failed to render thumbnail"))
                    return
                }
                let response = GCDWebServerDataResponse(data: data, contentType: "image/jpeg")
                completion(response)
            }
        }
    }

    static func makeDownloadResponse(
        identifier: String,
        kind: TransferLibraryKind,
        completion: @escaping (GCDWebServerResponse?) -> Void
    ) {
        Task {
            let status = await ensureReadPermission()
            guard isAuthorized(status) else {
                completion(errorResponse(statusCode: 403, message: "Photo access not granted"))
                return
            }

            guard let asset = asset(with: identifier, kind: kind) else {
                completion(errorResponse(statusCode: 404, message: "Asset not found"))
                return
            }

            let resources = PHAssetResource.assetResources(for: asset)
            guard let resource = preferredResource(from: resources, for: kind) ?? resources.first else {
                completion(errorResponse(statusCode: 404, message: "Asset resource not found"))
                return
            }

            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("TransferLibraryCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + "-" + resource.originalFilename)

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { error in
                if let error {
                    completion(errorResponse(statusCode: 500, message: error.localizedDescription))
                    return
                }
                completion(GCDWebServerFileResponse(file: tempURL.path, isAttachment: true))
            }
        }
    }

    private static func ensureReadPermission() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return status
    }

    private static func isAuthorized(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    private static func authorizationText(for status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .limited: return "limited"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
    }

    private static func asset(with identifier: String, kind: TransferLibraryKind) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject, asset.mediaType == kind.mediaType else {
            return nil
        }
        return asset
    }

    private static func preferredResource(from resources: [PHAssetResource], for kind: TransferLibraryKind) -> PHAssetResource? {
        switch kind {
        case .image:
            return resources.first {
                $0.type == .photo || $0.type == .fullSizePhoto
            }
        case .video:
            return resources.first {
                $0.type == .video || $0.type == .fullSizeVideo
            }
        }
    }

    private static func errorResponse(statusCode: Int, message: String) -> GCDWebServerDataResponse {
        let data = (try? JSONSerialization.data(withJSONObject: ["error": message], options: [])) ?? Data("{}".utf8)
        let response = GCDWebServerDataResponse(data: data, contentType: "application/json; charset=utf-8")
        response.statusCode = statusCode
        return response
    }

    private static func urlEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
