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
            return "Microphone access is denied. Please enable it from Settings."
        case let .recordingFailed(reason):
            return "Recording failed: \(reason)"
        case let .processingFailed(reason):
            return "Processing failed: \(reason)"
        case let .exportFailed(reason):
            return "Export failed: \(reason)"
        case .invalidInput:
            return "Invalid audio input."
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
