import SwiftUI

extension URL: Identifiable {
  public var id: Self { self }
}

extension View {

  // See also: prior art
  // https://forums.swift.org/t/conditionally-apply-modifier-in-swiftui/32815
  // https://fivestars.blog/swiftui/conditional-modifiers.html

  /// Conditionally apply a modifier to the view based on a boolean value.
  /// - Returns: `modifier(self)` if `condition` is true; `self` otherwise.
  @ViewBuilder
  public func `if`<T: View>(_ condition: Bool, _ modifier: (Self) -> T) -> some View {
    if condition {
      modifier(self)
    } else {
      self
    }
  }

  /// Conditionally apply a modifier to the view based on the presence of an optional value.
  /// - Returns: `modifier(self)` if `condition` is true; `self` otherwise.
  @ViewBuilder
  public func `ifLet`<T: View, U>(_ value: U?, _ modifier: (Self, U) -> T) -> some View {
    if let value = value {
      modifier(self, value)
    } else {
      self
    }
  }

  /// Erase the type of a view by wrapping it in an `AnyView`.
  ///
  /// Helps to work around the lack of support for opaque types (`some View`) as a function parameter type.
  public func eraseToAnyView() -> AnyView {
    return AnyView(self)
  }

  /// Positions this view within an invisible frame that stretches to fill its parent's size on the specified axis/axes.
  public func flexibleFrame(_ flexibleAxis: Axis.Set = [.horizontal, .vertical], alignment: Alignment = .center) -> some View {
    return frame(
      maxWidth: flexibleAxis.contains(.horizontal) ? .infinity : nil,
      maxHeight: flexibleAxis.contains(.vertical) ? .infinity : nil,
      alignment: alignment)
  }

}

extension Text {
  public init(_ date: Date, dateStyle: DateFormatter.Style) {
    let formatter = DateFormatter()
    formatter.dateStyle = dateStyle
    self.init(verbatim: formatter.string(from: date))
  }

  public init(_ date: Date, formatter: DateFormatter) {
    self.init(verbatim: formatter.string(from: date))
  }

  @available(*, deprecated, message: "Date formatting is buggy in 14.1: https://developer.apple.com/forums/thread/665081")
  public init<S: ReferenceConvertible>(_ subject: S, formatter: Formatter) {
    fatalError()
  }

  @available(*, deprecated, message: "Date formatting is buggy in 14.1: https://developer.apple.com/forums/thread/665081")
  public init(_ date: Date, style: DateStyle) {
    fatalError()
  }
}
