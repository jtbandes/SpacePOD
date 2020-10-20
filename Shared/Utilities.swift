import Foundation
import Combine
import SwiftUI

//infix operator ??= : AssignmentPrecedence
//public func ??=<T>(lhs: inout T?, rhs: @autoclosure () -> T?) {
//  lhs = lhs ?? rhs()
//}

public func with<T>(_ arg: T, _ body: (inout T) -> Void) -> T {
  var result = arg
  body(&result)
  return result
}
public func mutate<T>(_ arg: inout T, _ body: (inout T) -> Void) {
  body(&arg)
}

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
  case invalidImage
  case unsupportedAsset
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
      return "Invalid video ID “\(str)”."
    case .invalidImage:
      return "The image couldn’t be loaded."
    case .unsupportedAsset:
      return "This media couldn’t be displayed."
    }
  }
}

public extension Optional {
  func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
    if let self = self {
      return self
    }
    throw error()
  }

  func orFatalError(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) -> Wrapped {
    if let self = self {
      return self
    }
    fatalError(message(), file: file, line: line)
  }

  // https://forums.swift.org/t/mutating-t-with-a-default-value-or-returning-inout-or-extending-any/40593
  subscript(withDefault value: @autoclosure () -> Wrapped) -> Wrapped {
    get {
      return self ?? value()
    }
    set {
      self = newValue
    }
//    _read {
//      yield self ?? value()
//    }
//    _modify {
//      if self == nil { self = value() }
//      yield &self!
//    }
  }

  func asResult<E>(ifNil makeError: @autoclosure () -> E) -> Result<Wrapped, E> {
    if let self = self {
      return .success(self)
    }
    return .failure(makeError())
  }
}

public extension DateComponents {
  init(YMDString string: String) throws {
    let components = string.split(separator: "-")
    guard components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) else {
      throw APODErrors.invalidDate(string)
    }
    self = DateComponents(year: year, month: month, day: day)
  }
}

extension DateFormatter {
  static let monthDay = with(DateFormatter()) {
    $0.setLocalizedDateFormatFromTemplate("MMM dd")
  }
}

public enum BinarySearchResult<T> {
  case present(index: T)
  case absent(insertionIndex: T)
}

public extension RangeReplaceableCollection where Element: Comparable {
  func binarySearch(_ element: Element) -> BinarySearchResult<Index> {
    var low = startIndex
    var high = endIndex
    while low < high {
      let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
      if element == self[mid] {
        return .present(index: mid)
      } else if element < self[mid] {
        high = mid
      } else {
        low = index(after: mid)
      }
    }
    return .absent(insertionIndex: low)
  }
}

public extension URLSession {
  func downloadTaskPublisher(for url: URL) -> AnyPublisher<URL, Error> {
    let subject = PassthroughSubject<URL, Error>()
    let task = downloadTask(with: url) { (location, response, error) in
      if let error = error {
        subject.send(completion: .failure(error))
        return
      }
      guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
        subject.send(completion: .failure(URLError(.badServerResponse)))
        return
      }
      guard let location = location else {
        subject.send(completion: .failure(URLError(.cannotOpenFile)))
        return
      }
      subject.send(location)
      subject.send(completion: .finished)
    }
    return subject.handleEvents(
      receiveCancel: { task.cancel() },
      receiveRequest: { if $0 > .none { task.resume() } })
      .eraseToAnyPublisher()
  }
}

// Prior art:
// https://forums.swift.org/t/conditionally-apply-modifier-in-swiftui/32815
// https://fivestars.blog/swiftui/conditional-modifiers.html
extension View {
  @ViewBuilder
  func `if`<T: View>(_ condition: Bool, _ modifier: (Self) -> T) -> some View {
    if condition {
      modifier(self)
    } else {
      self
    }
  }

  @ViewBuilder
  func `ifLet`<T: View, U>(_ value: U?, _ modifier: (Self, U) -> T) -> some View {
    if let value = value {
      modifier(self, value)
    } else {
      self
    }
  }

  public func flexibleFrame(_ flexibleAxis: Axis.Set = [.horizontal, .vertical], alignment: Alignment = .center) -> some View {
    return frame(
      maxWidth: flexibleAxis.contains(.horizontal) ? .infinity : nil,
      maxHeight: flexibleAxis.contains(.vertical) ? .infinity : nil,
      alignment: alignment)
  }

  public func eraseToAnyView() -> AnyView {
    return AnyView(self)
  }
}

extension UIImage {
  func decoded() -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, /*opaque*/true, scale)
    defer {
      UIGraphicsEndImageContext()
    }
    draw(at: .zero)
    return UIGraphicsGetImageFromCurrentImageContext() ?? self
  }
}

extension AnyTransition {
  public static func animatableModifier<Body: View>(_ modifier: @escaping (AnyAnimatableModifier.Content, CGFloat) -> Body) -> AnyTransition {
    return .modifier(active: AnyAnimatableModifier(modifier, 1), identity: AnyAnimatableModifier(modifier, 0))
  }
}

public struct AnyAnimatableModifier: AnimatableModifier {
  public typealias AnimatableData = CGFloat
  public var animatableData: CGFloat

  private var modifier: (Content, CGFloat) -> AnyView

  public init<Body: View>(_ modifier: @escaping (Content, CGFloat) -> Body, _ animatableData: CGFloat) {
    self.animatableData = animatableData
    self.modifier = { AnyView(modifier($0, $1)) }
  }

  public func body(content: Content) -> some View {
    return modifier(content, animatableData)
  }
}
