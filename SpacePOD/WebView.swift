import SwiftUI
import WebKit

/// A view that displays a WKWebView.
struct WebView: UIViewRepresentable {
  let url: URL

  func makeCoordinator() -> Coordinator {
    return Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let view = WKWebView()
    view.isOpaque = false
    view.backgroundColor = .black
    view.scrollView.backgroundColor = .black
    context.coordinator.currentURL = url
    view.load(URLRequest(url: url))
    return view
  }

  /// Update the web view to show the URL represented by `self`. Does nothing if the loaded URL has not changed.
  func updateUIView(_ uiView: WKWebView, context: Context) {
    if url != context.coordinator.currentURL {
      uiView.load(URLRequest(url: url))
    }
  }

  class Coordinator {
    /// The currently displayed URL. Used in order to avoid duplicate updates in `updateUIView(_:context:)`.
    var currentURL: URL?
  }
}
