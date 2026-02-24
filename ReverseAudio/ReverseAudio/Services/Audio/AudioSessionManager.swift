//
//  AudioSessionManager.swift
//  ReverseAudio
//

import AVFoundation
import Foundation

final class AudioSessionManager {
    private let session: AVAudioSession

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func configureForRecording() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setPreferredSampleRate(44_100)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func configureForPlayback() throws {
        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
