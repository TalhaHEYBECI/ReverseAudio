import AVFoundation
import Combine
import Foundation

@MainActor
final class ReverseAudioDemoViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case recording
        case processing
        case ready
        case permissionDenied
        case error(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var originalURL: URL?
    @Published private(set) var reversedURL: URL?
    @Published private(set) var isPlayingOriginal = false
    @Published private(set) var isPlayingReversed = false
    @Published private(set) var processingMs: Int?

    private let service: ReverseAudioServiceType
    private var originalPlayer: AVAudioPlayer?
    private var reversedPlayer: AVAudioPlayer?

    init(service: ReverseAudioServiceType) {
        self.service = service
    }

    convenience init() {
        self.init(service: ReverseAudioService())
    }

    var isProcessing: Bool {
        if case .processing = status { return true }
        return false
    }

    var canReverse: Bool {
        originalURL != nil && !isProcessing
    }

    var canShareReversed: Bool {
        reversedURL != nil && !isProcessing
    }

    var errorText: String? {
        if case let .error(text) = status { return text }
        return nil
    }

    func retryFromError() {
        if case .error = status {
            status = .idle
        }
    }

    func toggleRecording() async {
        switch status {
        case .recording:
            do {
                let url = try await service.stopRecording()
                originalURL = url
                status = .idle
            } catch {
                status = .error(error.localizedDescription)
            }
        default:
            let granted = await service.requestMicPermission()
            guard granted else {
                status = .permissionDenied
                return
            }

            do {
                try service.startRecording(maxDuration: 15)
                status = .recording
                reversedURL = nil
                processingMs = nil
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    func reverse() async {
        guard let originalURL else { return }
        status = .processing
        do {
            let result = try await service.reverseAudio(inputURL: originalURL)
            self.originalURL = result.originalURL
            reversedURL = result.reversedURL
            processingMs = result.processingMs
            status = .ready
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func toggleOriginalPlayback() {
        guard let originalURL else { return }
        do {
            if isPlayingOriginal {
                originalPlayer?.pause()
                isPlayingOriginal = false
                return
            }
            reversedPlayer?.pause()
            isPlayingReversed = false

            let player = try service.makePlayer(url: originalURL)
            player.play()
            originalPlayer = player
            isPlayingOriginal = true
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func toggleReversedPlayback() {
        guard let reversedURL else { return }
        do {
            if isPlayingReversed {
                reversedPlayer?.pause()
                isPlayingReversed = false
                return
            }
            originalPlayer?.pause()
            isPlayingOriginal = false

            let player = try service.makePlayer(url: reversedURL)
            player.play()
            reversedPlayer = player
            isPlayingReversed = true
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func stopAllPlayback() {
        originalPlayer?.stop()
        reversedPlayer?.stop()
        isPlayingOriginal = false
        isPlayingReversed = false
    }
}
