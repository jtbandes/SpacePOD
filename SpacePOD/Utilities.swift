import UIKit
import StoreKit

enum UserDefaultsKeys {
  static let lastVersionPromptedForReview = "SpacePOD.LastVersionPromptedForReview"
  static let lastReviewPromptDate = "SpacePOD.LastReviewPromptDate"
  static let detailsViewedTimes = "SpacePOD.DetailsViewedTimes"
  static let openedFromWidgetTimes = "SpacePOD.OpenedFromWidgetTimes"
  static let continuedUserActivityTimes = "SpacePOD.ContinueUserActivityTimes"
}

enum UserAction {
  case detailsViewed
  case openedFromWidget
  case continuedUserActivity
}

extension UIApplication {
  /// The currently visible (topmost) view controller. Used for presenting modal dialogs such as a share sheet.
  /// From @mxcl: https://gist.github.com/mxcl/36de8f6f13e53872f11248d7ff2b1abc
  var visibleViewController: UIViewController? {
    var vc = UIApplication.shared.windows.first(where: \.isKeyWindow)?.rootViewController
    while let presentedVc = vc?.presentedViewController {
      if let navVc = (presentedVc as? UINavigationController)?.viewControllers.last {
        vc = navVc
      } else if let tabVc = (presentedVc as? UITabBarController)?.selectedViewController {
        vc = tabVc
      } else {
        vc = presentedVc
      }
    }
    return vc
  }
}

extension UIViewControllerTransitionCoordinator {
  // Fix UIKit method that's named poorly for trailing closure style
  @discardableResult
  func animateAlongsideTransition(_ animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
    return animate(alongsideTransition: animation, completion: completion)
  }
}

func incrementActionCount(_ key: String) -> Int {
  var count = UserDefaults.standard.integer(forKey: key)
  count += 1
  UserDefaults.standard.set(count, forKey: key)
  return count
}

/// Request an app rating or review after a user action, if some basic conditions have been met.
/// https://developer.apple.com/documentation/storekit/requesting_app_store_reviews
func maybeRequestReview(because action: UserAction, delay: DispatchTimeInterval) {
  guard let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String else {
    print("Unable to determine bundle version")
    return
  }

  guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
    print("Unable to find active scene")
    return
  }

  let lastReviewedVersion = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersionPromptedForReview)
  if bundleVersion == lastReviewedVersion {
    print("Already reviewed this version")
    return
  }

  if let lastReviewedDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastReviewPromptDate) as? Date {
    if Date().timeIntervalSince(lastReviewedDate) < 7*24*60*60 {
      print("Asked for review recently, skipping")
      return
    }
  }

  switch action {
  case .detailsViewed:
    if incrementActionCount(UserDefaultsKeys.detailsViewedTimes) < 3 {
      return
    }

  case .openedFromWidget:
    if incrementActionCount(UserDefaultsKeys.openedFromWidgetTimes) < 4 {
      return
    }

  case .continuedUserActivity:
    if incrementActionCount(UserDefaultsKeys.continuedUserActivityTimes) < 2 {
      return
    }
  }

  print("Requesting review")
  UserDefaults.standard.set(bundleVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReview)
  UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastReviewPromptDate)
  UserDefaults.standard.set(0, forKey: UserDefaultsKeys.detailsViewedTimes)
  UserDefaults.standard.set(0, forKey: UserDefaultsKeys.openedFromWidgetTimes)

  DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
    SKStoreReviewController.requestReview(in: scene)
  }
}
