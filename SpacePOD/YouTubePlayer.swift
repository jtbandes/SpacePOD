import SpacePODShared
import SwiftUI
import YTPlayerView

/// A view that displays a YouTube video player (internally using a YTPlayerView, which wraps WKWebView with an iframe).
struct YouTubePlayer: UIViewRepresentable {
  /// The video ID to play, for example "oHg5SJYRHA0".
  let videoId: String

  func makeCoordinator() -> Coordinator {
    return Coordinator()
  }

  func makeUIView(context: Context) -> YTPlayerView {
    context.coordinator.currentId = videoId
    return configure(YTPlayerView()) {
      $0.delegate = context.coordinator
      $0.load(
        withVideoId: videoId,
        playerVars: [
          // Prevent the video from automatically entering full screen mode.
          "playsinline": 1,
        ])
    }
  }

  /// Update the player to match the video represented by `self`. Does nothing if the presented video ID has not changed.
  func updateUIView(_ uiView: YTPlayerView, context: Context) {
    // In practice, this method is only called when dismissing the details sheet, so the ID doesn't actually change.
    if context.coordinator.currentId != videoId {
      DBG("Updating video id: \(context.coordinator.currentId ?? "nil") -> \(videoId). This should likely never happen.")
      uiView.cueVideo(byId: videoId, startSeconds: 0)
      context.coordinator.currentId = videoId
    }
  }

  /// A reference type whose lifetime is tied to the player view, acting as its delegate.
  class Coordinator: NSObject, YTPlayerViewDelegate {
    /// The currently displayed video ID. Used in order to avoid duplicate updates in `updateUIView(_:context:)`.
    var currentId: String?

    // Show a spinner while the video loads.
    func playerViewPreferredInitialLoading(_ playerView: YTPlayerView) -> UIView? {
      return configure(UIActivityIndicatorView()) {
        $0.startAnimating()
      }
    }

    // Set the web view's background color to clear so there's no white flicker when the page first loads.
    func playerViewPreferredWebViewBackgroundColor(_ playerView: YTPlayerView) -> UIColor {
      return .clear
    }
  }
}
