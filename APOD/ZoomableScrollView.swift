import SwiftUI
import Combine
import APODShared

class CenteringScrollView: UIScrollView {
  func centerContent() {
    assert(subviews.count == 1)
    mutate(&subviews[0].frame) {
      // not clear why view.center.{x,y} = bounds.mid{X,Y} doesn't work -- maybe transform?
      $0.origin.x = max(0, bounds.width - $0.width) / 2
      $0.origin.y = max(0, bounds.height - $0.height) / 2
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    centerContent()
  }
}

struct ZoomableScrollView<Content: View>: UIViewControllerRepresentable {
  private var content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func makeUIViewController(context: Context) -> ViewController {
    return ViewController(coordinator: context.coordinator)
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(hostingController: UIHostingController(rootView: self.content))
  }

  func updateUIViewController(_ viewController: ViewController, context: Context) {
    viewController.update(self.content)
  }

  // MARK: - ViewController

  class ViewController: UIViewController, UIScrollViewDelegate {
    let coordinator: Coordinator
    let scrollView = CenteringScrollView()//UIScrollView()
    var cancellable: Cancellable?

    private var hostedView: UIView { coordinator.hostingController.view! }

    private var contentSizeConstraints: [NSLayoutConstraint] = [] {
      willSet { NSLayoutConstraint.deactivate(contentSizeConstraints) }
      didSet { NSLayoutConstraint.activate(contentSizeConstraints) }
    }

    required init?(coder: NSCoder) { fatalError() }
    init(coordinator: Coordinator) {
      self.coordinator = coordinator
      super.init(nibName: nil, bundle: nil)
      self.view = scrollView

      scrollView.delegate = self  // for viewForZooming(in:)
      scrollView.maximumZoomScale = 10
      scrollView.minimumZoomScale = 1
      scrollView.bouncesZoom = true
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.clipsToBounds = false

      let hostedView = coordinator.hostingController.view!
      hostedView.translatesAutoresizingMaskIntoConstraints = false
      scrollView.addSubview(hostedView)
      NSLayoutConstraint.activate([
        hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      ])

      cancellable = scrollView.publisher(for: \.bounds).map(\.size).removeDuplicates()
        .sink { [unowned self] size in
          view.setNeedsUpdateConstraints()
        }
    }

    func update(_ content: Content) {
      coordinator.hostingController.rootView = content
      scrollView.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints() {
      super.updateViewConstraints()
      let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
      contentSizeConstraints = [
        hostedView.widthAnchor.constraint(equalToConstant: hostedContentSize.width),
        hostedView.heightAnchor.constraint(equalToConstant: hostedContentSize.height),
      ]
    }

    override func viewDidAppear(_ animated: Bool) {
      scrollView.zoom(to: hostedView.bounds, animated: false)
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()

      let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
      scrollView.minimumZoomScale = min(
        scrollView.bounds.width / hostedContentSize.width,
        scrollView.bounds.height / hostedContentSize.height)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      // For some reason this is needed in both didZoom and layoutSubviews, thanks to https://medium.com/@ssamadgh/designing-apps-with-scroll-views-part-i-8a7a44a5adf7
      // Sometimes this seems to work (view animates size and position simultaneously from current position to center) and sometimes it does not (position snaps to center immediately, size change animates)
      self.scrollView.centerContent()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
      coordinator.animateAlongsideTransition { [self] context in
        scrollView.zoom(to: hostedView.bounds, animated: false)
      }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      return hostedView
    }
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, UIScrollViewDelegate {
    var hostingController: UIHostingController<Content>

    init(hostingController: UIHostingController<Content>) {
      self.hostingController = hostingController
    }
  }
}
