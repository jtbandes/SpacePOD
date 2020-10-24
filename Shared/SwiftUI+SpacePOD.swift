import SwiftUI

extension View {

  // See also: prior art
  // https://forums.swift.org/t/conditionally-apply-modifier-in-swiftui/32815
  // https://fivestars.blog/swiftui/conditional-modifiers.html

  /// Conditionally apply a modifier to the view based on a boolean value.
  /// - Returns: `modifier(self)` if `condition` is true; `self` otherwise.
  @ViewBuilder
  func `if`<T: View>(_ condition: Bool, _ modifier: (Self) -> T) -> some View {
    if condition {
      modifier(self)
    } else {
      self
    }
  }

  /// Conditionally apply a modifier to the view based on the presence of an optional value.
  /// - Returns: `modifier(self)` if `condition` is true; `self` otherwise.
  @ViewBuilder
  func `ifLet`<T: View, U>(_ value: U?, _ modifier: (Self, U) -> T) -> some View {
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
