import SwiftUI
import SpacePODShared
import UIKit

extension String {
  func withAttributes(_ attrs: [NSAttributedString.Key : Any]) -> NSAttributedString {
    return NSAttributedString(string: self, attributes: attrs)
  }
}

extension UIFont {
  static func preferredFont(forTextStyle textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular, design: UIFontDescriptor.SystemDesign = .default) -> UIFont {
    if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle).withDesign(design) {
      var traits = descriptor.fontAttributes[.traits, default: [:]] as! NSDictionary as Dictionary
      traits[UIFontDescriptor.TraitKey.weight.rawValue as NSObject] = weight.rawValue as AnyObject
      return UIFont(descriptor: descriptor.addingAttributes([.traits: traits]), size: 0)
    } else {
      return UIFont.preferredFont(forTextStyle: textStyle)
    }
  }
}

/// Build a NSAttributedString by joining components with line breaks.
/// Inspired by: https://medium.com/@carson.katri/create-your-first-function-builder-in-5-minutes-b4a717390671
@resultBuilder struct AttributedStringBuilder {
  static func buildBlock(_ pieces: NSAttributedString?...) -> NSAttributedString {
    let content = NSMutableAttributedString()
    for case let piece? in pieces {
      if content.length != 0 {
        content.append(NSAttributedString(string: "\n"))
      }
      content.append(piece)
    }
    return content
  }
  static func buildExpression(_ string: NSAttributedString?) -> NSAttributedString? {
    return string
  }
  static func buildExpression(_ string: String) -> NSAttributedString? {
    return NSAttributedString(string: string)
  }
  static func buildIf(_ value: NSAttributedString?) -> NSAttributedString? {
    return value
  }
  static func buildEither(first value: NSAttributedString?) -> NSAttributedString? {
    return value
  }
  static func buildEither(second value: NSAttributedString?) -> NSAttributedString? {
    return value
  }
}

/// A selectable, scrollable text view. (SwiftUI's `Text` is not selectable.) Wrapping in a SwiftUI ScrollView instead might be nice,
/// but it's hard to get the UITextView's height to automatically adjust based on the text, while correctly handling orientation changes etc.
/// Some attempts have been made: <https://stackoverflow.com/q/16868117/23649>, <https://stackoverflow.com/a/58639072/23649> but it was simpler for this use case to just use the default scrolling behavior.
struct TextView: UIViewRepresentable {
  let content: NSAttributedString

  init(@AttributedStringBuilder _ buildContent: () -> NSAttributedString) {
    self.content = buildContent()
  }

  func makeUIView(context: Context) -> UITextView {
    return configure(UITextView()) {
      $0.contentInset.left = 12
      $0.contentInset.right = 12
      $0.isSelectable = true
      $0.isEditable = false
      $0.attributedText = content
      $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    uiView.attributedText = content
  }
}
