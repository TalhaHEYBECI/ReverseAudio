//
//  ReverseAudioService.swift
//  ReverseAudio
//

import AVFoundation
import Foundation
import OSLog

final class ReverseAudioService: ReverseAudioServiceType {
    private let sessionManager: AudioSessionManager
    private let recorderService: AudioRecorderService
    private let reverseProcessor: AudioReverseProcessor
    private let exportService: AudioExportService
    private let fileManager: FileManager
    private let defaultCleanupThreshold: TimeInterval = 24 * 60 * 60

    init(
        sessionManager: AudioSessionManager = AudioSessionManager(),
        recorderService: AudioRecorderService = AudioRecorderService(),
        reverseProcessor: AudioReverseProcessor = AudioReverseProcessor(),
        exportService: AudioExportService = AudioExportService(),
        fileManager: FileManager = .default
    ) {
        self.sessionManager = sessionManager
        self.recorderService = recorderService
        self.reverseProcessor = reverseProcessor
        self.exportService = exportService
        self.fileManager = fileManager
    }

    func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(maxDuration: TimeInterval = 15) throws {
        try sessionManager.configureForRecording()
        try recorderService.startRecording(maxDuration: maxDuration)
    }

    func stopRecording() async throws -> URL {
        let recordedURL = try await recorderService.stopRecording()
        let duration = try audioDuration(for: recordedURL)
        guard duration > 0 else {
            throw ReverseAudioError.invalidInput
        }
        return recordedURL
    }

    func reverseAudio(inputURL: URL) async throws -> ReverseAudioResult {
        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw ReverseAudioError.invalidInput
        }

        let duration = try audioDuration(for: inputURL)
        guard duration > 0 else {
            throw ReverseAudioError.invalidInput
        }

        let processingDirectory = try fileManager.reverseAudioDirectoryURL(for: .processing)
        let intermediatePCMURL = processingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")

        let startedAt = DispatchTime.now()
        try await reverseProcessor.reverse(inputURL: inputURL, outputURL: intermediatePCMURL)
        let reversedM4AURL = try await exportService.exportToM4A(
            inputURL: intermediatePCMURL,
            fileName: "reversed-\(UUID().uuidString)"
        )
        let processingMs = elapsedMilliseconds(since: startedAt)

        ReverseAudioLog.processor.info("Reverse processing completed in \(processingMs)ms.")

        return ReverseAudioResult(
            originalURL: inputURL,
            reversedURL: reversedM4AURL,
            duration: duration,
            processingMs: processingMs
        )
    }

    func makePlayer(url: URL) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        return player
    }

    func exportToShareableFile(inputURL: URL, fileName: String) async throws -> URL {
        try await exportService.exportToM4A(inputURL: inputURL, fileName: fileName)
    }

    func cleanupTempFiles(olderThan: TimeInterval = 24 * 60 * 60) throws {
        let threshold = olderThan > 0 ? olderThan : defaultCleanupThreshold
        let recordingDirectory = try fileManager.reverseAudioDirectoryURL(for: .recordings)
        let processingDirectory = try fileManager.reverseAudioDirectoryURL(for: .processing)

        try fileManager.removeFiles(in: recordingDirectory, olderThan: threshold)
        try fileManager.removeFiles(in: processingDirectory, olderThan: threshold)
    }

    private func audioDuration(for url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
    }

    private func elapsedMilliseconds(since start: DispatchTime) -> Int {
        let elapsedNanos = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return Int(elapsedNanos / 1_000_000)
    }
}
