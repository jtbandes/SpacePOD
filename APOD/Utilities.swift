//
//  Utilities.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/29/20.
//

import UIKit

extension UIViewControllerTransitionCoordinator {
  // Fix UIKit method that's named poorly for trailing closure style
  @discardableResult
  func animateAlongsideTransition(_ animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool {
    return animate(alongsideTransition: animation, completion: completion)
  }
}
