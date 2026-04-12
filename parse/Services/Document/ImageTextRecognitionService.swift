import Foundation
import Vision

enum ImageTextRecognitionService {
    static func recognizeText(from fileURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(url: fileURL)
            try handler.perform([request])

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !lines.isEmpty else {
                throw ImageTextRecognitionError.noTextFound
            }

            return lines.joined(separator: "\n")
        }.value
    }
}

enum ImageTextRecognitionError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return AppLocalizer.localized("未识别到文字")
        }
    }
}
