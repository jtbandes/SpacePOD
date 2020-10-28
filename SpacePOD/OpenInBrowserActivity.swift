import UIKit

/// "Open in Safari" is not available as part of the default system activities.
class OpenInBrowserActivity: UIActivity {
  override var activityImage: UIImage? { UIImage(systemName: "safari") }
  override class var activityCategory: Category { .action }
  override var activityTitle: String? { "Open in Browser" }

  var url: URL?

  override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    for case let url as URL in activityItems where UIApplication.shared.canOpenURL(url) {
      return true
    }
    return false
  }

  override func prepare(withActivityItems activityItems: [Any]) {
    for case let url as URL in activityItems where UIApplication.shared.canOpenURL(url) {
      self.url = url
      break
    }
  }

  override func perform() {
    guard let url = url else {
      activityDidFinish(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { [weak self] success in
      self?.activityDidFinish(success)
    }
  }
}
