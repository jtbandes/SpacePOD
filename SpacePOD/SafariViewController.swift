//
//  SafariViewController.swift
//  Space!
//
//  Created by Jacob Bandes-Storch on 10/26/20.
//

import SwiftUI
import SafariServices
import SpacePODShared

struct SafariViewController: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let config = configure(SFSafariViewController.Configuration()) {
      /// Bar collapsing looks buggy when presented in a sheet.
      $0.barCollapsingEnabled = false
    }

    return configure(SFSafariViewController(url: url, configuration: config)) {
      /// The Safari view controller is presented out of process and doesn't automatically take our application's accent color.
      $0.preferredControlTintColor = UIColor(named: "AccentColor")
    }
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    print("Warning: unable to update SFSafariViewController")
  }
}
