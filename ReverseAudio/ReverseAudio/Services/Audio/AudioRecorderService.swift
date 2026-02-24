//
//  AudioRecorderService.swift
//  ReverseAudio
//

import AVFoundation
import Foundation
import OSLog

final class AudioRecorderService: NSObject {
    private let fileManager: FileManager
    private var recorder: AVAudioRecorder?
    private var lastRecordingURL: URL?
    private let hardMaxDuration: TimeInterval

    init(fileManager: FileManager = .default, hardMaxDuration: TimeInterval = 15) {
        self.fileManager = fileManager
        self.hardMaxDuration = hardMaxDuration
    }

    func startRecording(maxDuration: TimeInterval) throws {
        let recordingDirectory = try fileManager.reverseAudioDirectoryURL(for: .recordings)
        let outputURL = recordingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.prepareToRecord() else {
            throw ReverseAudioError.recordingFailed("Recorder preparation failed.")
        }

        let effectiveDuration = min(maxDuration, hardMaxDuration)
        guard recorder.record(forDuration: effectiveDuration) else {
            throw ReverseAudioError.recordingFailed("Recording could not be started.")
        }

        self.recorder = recorder
        lastRecordingURL = outputURL
        ReverseAudioLog.recorder.info("Recording started: \(outputURL.path, privacy: .public)")
    }

    func stopRecording() async throws -> URL {
        if let recorder, recorder.isRecording {
            recorder.stop()
        }

        guard let url = lastRecordingURL else {
            throw ReverseAudioError.recordingFailed("No recording URL available.")
        }

        guard fileManager.fileExists(atPath: url.path) else {
            throw ReverseAudioError.recordingFailed("Recorded file is missing.")
        }

        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else {
            throw ReverseAudioError.invalidInput
        }

        return url
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            ReverseAudioLog.recorder.error("Recording finished unsuccessfully.")
        }
    }
}
