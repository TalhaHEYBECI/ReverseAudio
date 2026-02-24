//
//  Logger+ReverseAudio.swift
//  ReverseAudio
//

import Foundation
import OSLog

enum ReverseAudioLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "ReverseAudio"
    static let service = Logger(subsystem: subsystem, category: "ReverseAudioService")
    static let recorder = Logger(subsystem: subsystem, category: "AudioRecorder")
    static let processor = Logger(subsystem: subsystem, category: "AudioReverseProcessor")
    static let export = Logger(subsystem: subsystem, category: "AudioExport")
}
