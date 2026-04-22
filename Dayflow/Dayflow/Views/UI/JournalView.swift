import AVFoundation
import AVKit
import SwiftUI

// MARK: - Journal Coordinator

/// Coordinates journal-level UI state that needs to be shared across the view hierarchy
@MainActor
final class JournalCoordinator: ObservableObject {
  @Published var showOnboardingVideo = false
  @Published var showRemindersAfterOnboarding = false
}

struct JournalView: View {
  // MARK: - Storage & State
  @AppStorage("hasCompletedJournalOnboarding") private var hasCompletedOnboarding: Bool = false
  @EnvironmentObject private var coordinator: JournalCoordinator
  @State private var showRemindersSheet: Bool = false

  var body: some View {
    ZStack {
      unlockedContent
        .transition(.opacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .sheet(isPresented: $showRemindersSheet) {
      JournalRemindersView(
        onSave: {
          showRemindersSheet = false
          coordinator.showRemindersAfterOnboarding = false
        },
        onCancel: {
          showRemindersSheet = false
          coordinator.showRemindersAfterOnboarding = false
        }
      )
    }
    .onChange(of: coordinator.showRemindersAfterOnboarding) { _, shouldShow in
      if shouldShow {
        showRemindersSheet = true
      }
    }
  }

  // MARK: - Unlocked Content
  @ViewBuilder
  var unlockedContent: some View {
    if hasCompletedOnboarding {
      // Main journal view
      JournalDayView(
        onSetReminders: { showRemindersSheet = true }
      )
      .frame(maxWidth: 980, alignment: .center)
      .padding(.horizontal, 12)
    } else {
      // Journal onboarding screen
      JournalOnboardingView(onStartOnboarding: {
        AnalyticsService.shared.capture("journal_onboarding_started")
        coordinator.showOnboardingVideo = true
      })
    }
  }

}

// MARK: - Journal Onboarding View

private struct JournalOnboardingView: View {
  var onStartOnboarding: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // Title
      Text("Set your intentions today")
        .font(.custom("InstrumentSerif-Regular", size: 42))
        .foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.15))
        .multilineTextAlignment(.center)

      // Description
      Text(
        "Dayflow helps you track your daily and longer term goals, gives you the space to reflect, and generates a summary of each day."
      )
      .font(.custom("Nunito-Regular", size: 16))
      .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.10).opacity(0.8))
      .multilineTextAlignment(.center)
      .frame(maxWidth: 640)
      .padding(.horizontal, 24)

      Spacer()

      // Start onboarding button
      Button(action: onStartOnboarding) {
        Text("Start onboarding")
          .font(.custom("Nunito-SemiBold", size: 16))
          .foregroundColor(Color(red: 0.35, green: 0.22, blue: 0.12))
          .padding(.horizontal, 32)
          .padding(.vertical, 12)
          .background(
            Capsule()
              .fill(
                LinearGradient(
                  colors: [
                    Color(red: 1.0, green: 0.96, blue: 0.92),
                    Color(red: 1.0, green: 0.90, blue: 0.82),
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .overlay(
                Capsule()
                  .stroke(Color(red: 0.92, green: 0.85, blue: 0.78), lineWidth: 1)
              )
          )
      }
      .buttonStyle(.plain)
      .pointingHandCursor()

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Journal Onboarding Video View

struct JournalOnboardingVideoView: View {
  var onComplete: () -> Void

  @State private var player: AVPlayer?
  @State private var hasCompleted = false
  @State private var playbackTimer: Timer?
  @State private var timeObserverToken: Any?
  @State private var endObserverToken: NSObjectProtocol?
  @State private var statusObservation: NSKeyValueObservation?

  var body: some View {
    ZStack {
      // Black background in case video doesn't load
      Color.black.ignoresSafeArea()

      if let player = player {
        JournalVideoPlayerView(player: player)
          .ignoresSafeArea()
      }
    }
    .onAppear {
      setupVideo()
    }
    .onDisappear {
      cleanup()
    }
  }

  private func setupVideo() {
    // Try root, then Videos subfolder, then mov fallback
    guard
      let videoURL = Bundle.main.url(forResource: "JournalOnboardingVideo", withExtension: "mp4")
        ?? Bundle.main.url(
          forResource: "JournalOnboardingVideo", withExtension: "mp4", subdirectory: "Videos")
        ?? Bundle.main.url(forResource: "JournalOnboardingVideo", withExtension: "mov")
        ?? Bundle.main.url(
          forResource: "JournalOnboardingVideo", withExtension: "mov", subdirectory: "Videos")
    else {
      print("⚠️ [JournalOnboardingVideoView] Video not found in bundle, completing immediately")
      completeVideo()
      return
    }

    let playerItem = AVPlayerItem(url: videoURL)
    player = AVPlayer(playerItem: playerItem)

    // Mute to prevent interrupting user's music
    player?.isMuted = true
    player?.volume = 0

    // Prevent system-level pause/interruptions
    player?.automaticallyWaitsToMinimizeStalling = false
    player?.actionAtItemEnd = .none

    // Monitor when near the end to start transition early
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      time in
      guard let duration = self.player?.currentItem?.duration,
        duration.isValid && duration.isNumeric
      else { return }

      let currentSeconds = time.seconds
      let totalSeconds = duration.seconds

      // Start transition 0.3 seconds before the end
      if currentSeconds >= totalSeconds - 0.3 && currentSeconds < totalSeconds {
        self.completeVideo()
      }
    }

    // Fallback: monitor actual completion
    endObserverToken = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { _ in
      completeVideo()
    }

    // Monitor for errors
    statusObservation = playerItem.observe(\.status) { item, _ in
      if item.status == .failed {
        print(
          "❌ [JournalOnboardingVideoView] Video failed: \(item.error?.localizedDescription ?? "Unknown")"
        )
        DispatchQueue.main.async {
          self.completeVideo()
        }
      }
    }

    // Start playing
    player?.play()

    // Timer to force resume if paused
    playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      if self.player?.rate == 0 && !self.hasCompleted {
        self.player?.play()
      }
    }
  }

  private func completeVideo() {
    guard !hasCompleted else { return }
    hasCompleted = true

    playbackTimer?.invalidate()
    playbackTimer = nil

    player?.pause()
    AnalyticsService.shared.capture("journal_onboarding_completed")
    onComplete()
  }

  private func cleanup() {
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
    if let token = endObserverToken {
      NotificationCenter.default.removeObserver(token)
      endObserverToken = nil
    }
    statusObservation = nil
    player?.pause()
    player = nil
  }
}

// MARK: - Non-Interactive Video Player

private struct JournalVideoPlayerView: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> JournalNonInteractivePlayerView {
    let view = JournalNonInteractivePlayerView()
    view.player = player
    view.controlsStyle = .none
    view.videoGravity = .resizeAspectFill
    view.showsFullScreenToggleButton = false
    view.allowsPictureInPicturePlayback = false
    view.wantsLayer = true
    return view
  }

  func updateNSView(_ nsView: JournalNonInteractivePlayerView, context: Context) {}
}

private class JournalNonInteractivePlayerView: AVPlayerView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    // Prevent all mouse interactions
    return nil
  }

  override func keyDown(with event: NSEvent) {
    // Ignore all keyboard events (including spacebar)
  }

  override func mouseDown(with event: NSEvent) {
    // Ignore mouse clicks
  }

  override func rightMouseDown(with event: NSEvent) {
    // Ignore right clicks
  }

  override var acceptsFirstResponder: Bool {
    return false
  }
}

// MARK: - Helpers

// Shake Effect
struct Shake: GeometryEffect {
  var amount: CGFloat = 10
  var shakesPerUnit: CGFloat = 3
  var animatableData: CGFloat

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(
      CGAffineTransform(
        translationX:
          amount * sin(animatableData * .pi * shakesPerUnit),
        y: 0))
  }
}

#Preview {
  JournalView()
}
