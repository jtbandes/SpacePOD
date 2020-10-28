import UIKit

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
