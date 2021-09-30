import SwiftUI

/// An invisible view that exposes its underlying UIView via a Binding, for use as a `sourceView` for popover presentation.
struct SourceView: UIViewRepresentable {
  let binding: Binding<UIView?>

  init(as binding: Binding<UIView?>) {
    self.binding = binding
  }

  class Coordinator {
    var binding: Binding<UIView?>
    init(binding: Binding<UIView?>) {
      self.binding = binding
    }
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(binding: self.binding)
  }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    self.binding.wrappedValue = view
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    context.coordinator.binding.wrappedValue = nil
    context.coordinator.binding = binding
    binding.wrappedValue = view
  }

  static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
    coordinator.binding.wrappedValue = nil
  }
}
