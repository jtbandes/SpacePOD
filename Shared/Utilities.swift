import Foundation
import Combine
import SwiftUI

/// Return `arg`, but first execute a closure to configure it.
///
/// This helps to reduce the need for local variables needed when modifying a temporary object, and allows replacing variables with constants when working with value types. For example:
/// ```
/// func makeView() -> UIView {
///   let view = UIView()
///   view.addSubview(UILabel())
///   view.addSubview(UIActivityIndicatorView())
///   return view
/// }
/// ```
/// can be rewritten as
/// ```
/// func makeView() -> UIView {
///   return configure(UIView()) {
///     $0.addSubview(UILabel())
///     $0.addSubview(UIActivityIndicatorView())
///   }
/// }
/// ```
public func configure<T>(_ arg: T, _ body: (inout T) -> Void) -> T {
  var result = arg
  body(&result)
  return result
}

/// Execute scoped modifications to `arg`.
///
/// Useful when multiple modifications need to be made to a single nested property. For example,
/// ```
/// view.frame.origin.x -= view.frame.width / 2
/// view.frame.origin.y -= view.frame.height / 2
/// ```
/// can be rewritten as
/// ```
/// modify(&view.frame) {
///   $0.origin.x -= $0.width / 2
///   $0.origin.y -= $0.height / 2
/// }
/// ```
///
public func mutate<T>(_ arg: inout T, _ body: (inout T) -> Void) {
  body(&arg)
}

/// Print a message in debug builds only. No-op in release builds.
public func DBG(_ item: Any) {
  #if DEBUG
  print(item)
  #endif
}

extension DefaultStringInterpolation {
  mutating func appendInterpolation(reflecting value: Any) {
    appendInterpolation(String(reflecting: value))
  }
}

/// Represents a value that is loading asynchronously, e.g. from the network.
public enum Loading<T> {
  case loading
  case loaded(T)
}

public enum APODErrors: Error {
  case invalidDate(String)
  case missingURL
  case emptyResponse
  case failureResponse(statusCode: Int)
  case invalidYouTubeVideo(String)
  case invalidVimeoVideo(String)
  case invalidImage
  case unsupportedAsset
  case fileCoordinationFailed
}

extension APODErrors: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidDate(let str):
      return "Couldn’t interpret “\(str)” as a date."
    case .missingURL:
      return "No photo was found."
    case .emptyResponse:
      return "The server returned no data."
    case .failureResponse(let status):
      return "The server returned an unexpected status: \(status)."
    case .invalidYouTubeVideo(let str):
      return "Invalid YouTube video ID “\(str)”."
    case .invalidVimeoVideo(let str):
      return "Invalid Vimeo video ID “\(str)”."
    case .invalidImage:
      return "The image couldn’t be loaded."
    case .unsupportedAsset:
      return "This media couldn’t be displayed."
    case .fileCoordinationFailed:
      return "An unknown error occurred while coordinating file access."
    }
  }
}

public enum Constants {
  /// The app group identifier shared between the main app & widget extension.
  public static let spaceAppGroupID = "group.SpacePOD"

  public static let userActivityType = "net.bandes-storch.SpacePOD.browsing"

  public static let widgetURL = URL(string: "space-widget-link://")!
}
