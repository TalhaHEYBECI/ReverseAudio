import SwiftUI
import UIKit

struct ReverseAudioDemoView: View {
    @StateObject private var viewModel = ReverseAudioDemoViewModel()
    @State private var shareURL: URL?
    @State private var isSharePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusView
                    controlsView
                    infoView
                }
                .padding()
            }
            .navigationTitle("Reverse Audio Demo")
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.status {
        case .permissionDenied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Microphone access is required.")
                    .font(.headline)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        case .processing:
            HStack(spacing: 12) {
                ProgressView()
                Text("Processing reverse audio...")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        case let .error(message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                Button("Retry") {
                    viewModel.retryFromError()
                }
                .buttonStyle(.bordered)
            }
        case .ready:
            Text("Ready: Reversed audio generated.")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .recording:
            Text("Recording in progress (max 15s)")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .idle:
            Text("Record a clip, reverse it, and share it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleRecording() }
            } label: {
                Text(viewModel.status == .recording ? "Stop" : "Record")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.status == .recording ? .red : .blue)
            .disabled(viewModel.isProcessing)

            Button("Reverse") {
                Task { await viewModel.reverse() }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
            .disabled(!viewModel.canReverse)

            HStack {
                Button(viewModel.isPlayingOriginal ? "Pause Original" : "Play Original") {
                    viewModel.toggleOriginalPlayback()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.originalURL == nil || viewModel.isProcessing)

                Button(viewModel.isPlayingReversed ? "Pause Reversed" : "Play Reversed") {
                    viewModel.toggleReversedPlayback()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.reversedURL == nil || viewModel.isProcessing)
            }

            Button("Share Reversed") {
                if let reversed = viewModel.reversedURL {
                    shareURL = reversed
                    isSharePresented = true
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canShareReversed)
        }
    }

    @ViewBuilder
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let original = viewModel.originalURL {
                Text("Original: \(original.lastPathComponent)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let reversed = viewModel.reversedURL {
                Text("Reversed: \(reversed.lastPathComponent)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let ms = viewModel.processingMs {
                Text("Processing time: \(ms) ms")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ReverseAudioDemoView()
}
