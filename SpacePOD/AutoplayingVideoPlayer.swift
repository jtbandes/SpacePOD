import AVKit
import SwiftUI
import SpacePODShared

// NOTE: Using AVPlayerViewController instead of VideoPlayer allows the fullscreen button to appear.
class AutoplayingAVPlayerViewController: AVPlayerViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.player?.play()
  }
}

struct AutoplayingVideoPlayer: UIViewControllerRepresentable {
  let url: URL

  func makeCoordinator() -> Coordinator {
    Coordinator(url: self.url)
  }

  func makeUIViewController(context: Context) -> some UIViewController {
    return configure(AutoplayingAVPlayerViewController()) {
      $0.player = context.coordinator.player
    }
  }

  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    print("Warning: AutoplayingVideoPlayer update not implemented")
  }

  class Coordinator {
    let player = AVQueuePlayer()
    var looper: AVPlayerLooper

    init(url: URL) {
      self.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }
  }
}
