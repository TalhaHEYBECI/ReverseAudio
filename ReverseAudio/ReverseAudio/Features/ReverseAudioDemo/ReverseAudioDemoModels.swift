import AVFoundation
import Foundation

enum ReverseAudioError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case processingFailed(String)
    case exportFailed(String)
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NSLocalizedString("error.permissionDenied", comment: "Microphone permission denied error")
        case let .recordingFailed(reason):
            return String(
                format: NSLocalizedString("error.recordingFailedFormat", comment: "Recording failure with reason"),
                reason
            )
        case let .processingFailed(reason):
            return String(
                format: NSLocalizedString("error.processingFailedFormat", comment: "Processing failure with reason"),
                reason
            )
        case let .exportFailed(reason):
            return String(
                format: NSLocalizedString("error.exportFailedFormat", comment: "Export failure with reason"),
                reason
            )
        case .invalidInput:
            return NSLocalizedString("error.invalidInput", comment: "Invalid input error")
        }
    }
}

struct ReverseAudioResult {
    let originalURL: URL
    let reversedURL: URL
    let processingMs: Int
}

// TODO(PR1 merge): replace these temporary demo types with shared core service from PR1.
protocol ReverseAudioServiceType {
    func requestMicPermission() async -> Bool
    func startRecording(maxDuration: TimeInterval) throws
    func stopRecording() async throws -> URL
    func reverseAudio(inputURL: URL) async throws -> ReverseAudioResult
    func makePlayer(url: URL) throws -> AVAudioPlayer
    func exportToShareableFile(inputURL: URL, fileName: String) async throws -> URL
}
