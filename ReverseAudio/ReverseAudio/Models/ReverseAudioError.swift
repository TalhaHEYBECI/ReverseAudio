//
//  ReverseAudioError.swift
//  ReverseAudio
//

import Foundation

public enum ReverseAudioError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed(String)
    case processingFailed(String)
    case exportFailed(String)
    case uploadFailed(String)
    case invalidInput

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is denied. Please enable access in Settings."
        case let .recordingFailed(reason):
            return "Recording failed: \(reason)"
        case let .processingFailed(reason):
            return "Audio processing failed: \(reason)"
        case let .exportFailed(reason):
            return "Export failed: \(reason)"
        case let .uploadFailed(reason):
            return "Upload failed: \(reason)"
        case .invalidInput:
            return "Invalid audio input."
        }
    }
}
