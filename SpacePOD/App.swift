import SwiftUI
import SpacePODShared

@main
struct SpacePOD: App {
  var body: some Scene {
    WindowGroup {
      ShakeHandler {
        ContentView()
      }
    }
  }
}

struct ShakeHandler<Content: View>: UIViewControllerRepresentable {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func makeUIViewController(context: Context) -> ShakeHandlingController<Content> {
    return ShakeHandlingController(rootView: content)
  }
  
  func updateUIViewController(_ uiViewController: ShakeHandlingController<Content>, context: Context) {
    uiViewController.rootView = content
  }
}

class ShakeHandlingController<Content: View>: UIHostingController<Content> {
  #if DEBUG
  let debugActions = configure(UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)) {
    $0.addAction(UIAlertAction(title: "Clear Cache", style: .destructive) { _ in APODClient.shared.debug_clearCache() })
    $0.addAction(UIAlertAction(title: "Cancel", style: .cancel))
  }
  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    guard motion == .motionShake else { return }

    if debugActions.presentingViewController != nil {
      debugActions.dismiss(animated: true)
    } else {
      (presentedViewController ?? self).present(debugActions, animated: true)
    }
  }
  #endif
}
