import SwiftUI
import Combine
import SpacePODShared
import WidgetKit
import UniformTypeIdentifiers

class ViewModel: ObservableObject {
  @Published var currentEntry: Loading<Result<APODEntry, Error>> = .loading

  private var cancellable: AnyCancellable?

  func reload() {
    print("Starting load (current: \(currentEntry))")
    cancellable ??= APODClient.shared.loadLatestImage()
      .receive(on: DispatchQueue.main)  // Avoid overlapping access to cancellable
      .sinkResult { [unowned self] in
        switch (currentEntry, $0) {
        case let (.loaded(.success(value)), .success(newValue)) where value.date == newValue.date:
          // If the date has not changed, don't reload the view.
          break
        default:
          currentEntry = .loaded($0)
          cancellable = nil
          WidgetCenter.shared.reloadAllTimelines()
        }
      }
  }
}

/// We present the UIActivityViewController imperatively rather than wrapping it with UIViewControllerRepresentable
/// because SwiftUI doesn't display it properly (full sheet instead of half sheet on iPhone) and the interactive swipe-to-dismiss
/// causes the `isPresented` binding to immediately become false, which suddenly removes the view controller.
/// The `sourceView` is required for iPad where the share sheet may be presented as a popover.
func presentShareSheet(_ entry: APODEntry, from sourceView: UIView?) {
  guard let visibleViewController = UIApplication.shared.visibleViewController else {
    print("No view controller from which to present share sheet")
    return
  }

  let activityVC: UIActivityViewController
  if case .image = entry.asset,
     let loadedImage = entry.loadImage(),
     let vc = shareSheetForImage(entry, loadedImage) {
    activityVC = vc
  } else if let webURL = entry.webURL {
    activityVC = UIActivityViewController(activityItems: [webURL], applicationActivities: [OpenInBrowserActivity()])
  } else {
    print("No image or web URL for share sheet")
    return
  }
  activityVC.popoverPresentationController?.sourceView = sourceView
  visibleViewController.present(activityVC, animated: true)
}

func shareSheetForImage(_ entry: APODEntry, _ image: UIImage) -> UIActivityViewController? {
  // Our cache saves images without file extensions, so if we want the extension to be shown
  // when sharing a URL, we need to actually create a new temporary file.

  let filename: String
  if let uti = image.cgImage?.utType,
     let ext = UTType(uti as String)?.preferredFilenameExtension {
    filename = "\(entry.date.description).\(ext)"
  } else {
    filename = entry.date.description
  }

  let activityVC: UIActivityViewController
  let tmpDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
  var tmpFile = tmpDir.appendingPathComponent(filename)
  do {
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    try entry.coordinateReadingImage { imageURL in
      do {
        try FileManager.default.linkItem(at: imageURL, to: tmpFile)
      } catch {
        print("Link failed, falling back to copy:", error)
        try FileManager.default.copyItem(at: imageURL, to: tmpFile)
      }
    }
    // Update creation/modification dates so the photo shows up in the newest spot in the photos library.
    try tmpFile.setResourceValues(configure(URLResourceValues()) {
      let now = Date()
      $0.creationDate = now
      $0.contentModificationDate = now
    })

    activityVC = UIActivityViewController(activityItems: [tmpFile], applicationActivities: nil)
  } catch {
    print("Unable to create temporary file: \(error)")
    return nil
  }

  activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
    do {
      try FileManager.default.removeItem(at: tmpFile)
    } catch {
      print("Unable to remove temporary file: \(error)")
    }
  }
  return activityVC
}

struct ContentView: View {
  @Environment(\.scenePhase) var scenePhase
  @StateObject var viewModel = ViewModel()
  @State var titleShown = true
  @State var detailsShown = false
  @State var urlForWebView: URL?
  @State var shareButton: UIView?

  func titleView(for entry: APODEntry) -> some View {
    titleView(date: entry.date.asDate(), title: entry.title, copyright: entry.copyright)
  }

  @ViewBuilder
  func titleView(date: Date?, title: String?, copyright: String?) -> some View {
    VStack(alignment: .leading) {
      if let date = date {
        Text(date, dateStyle: .long)
          .font(.system(.caption))
          .foregroundColor(.secondary)
          .unredacted()
      }
      if let title = title {
        Text(title)
          .font(.system(.headline))
          .multilineTextAlignment(.leading)
      }
      if let copyright = copyright {
        Text(copyright)
          .font(.system(.subheadline))
          .foregroundColor(.secondary)
      }
    }
    .flexibleFrame(.horizontal, alignment: .leading)
    .padding()
    .contentShape(Rectangle())
    .shadow(color: .black, radius: 2, x: 0.0, y: 0.0)
  }

  func detailsSheet(_ entry: APODEntry) -> some View {
    TextView {
      if let title = entry.title {
        title.withAttributes([
          .font: UIFont.preferredFont(forTextStyle: .title1, weight: .heavy),
          .foregroundColor: UIColor.label,
        ])
      }
      if let copyright = entry.copyright {
        copyright.withAttributes([
          .font: UIFont.preferredFont(forTextStyle: .callout),
          .foregroundColor: UIColor.secondaryLabel,
        ])
      }
      "" // line break
      if let explanation = entry.explanation {
        explanation.withAttributes([
          .font: UIFont.preferredFont(forTextStyle: .body, design: .serif),
          .foregroundColor: UIColor.label,
        ])
      } else {
        "No details available".withAttributes([
          .font: UIFont.preferredFont(forTextStyle: .body, design: .serif),
          .foregroundColor: UIColor.secondaryLabel,
        ])
      }
    }
    .padding()
    .navigationTitle(
      entry.date.asDate().map { Text($0, dateStyle: .long) } ?? Text("")
    )
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Done") { detailsShown = false }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { urlForWebView = entry.webURL }) {
          Image(systemName: "safari").imageScale(.large)
        }.sheet(item: $urlForWebView) {
          SafariViewController(url: $0)
        }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { presentShareSheet(entry, from: shareButton) }) {
          ZStack {
            Text("")
          Image(systemName: "square.and.arrow.up")
            .imageScale(.large)
            .background(SourceView(as: $shareButton))
          }
        }
      }
    }
  }

  @ViewBuilder
  func entryBody(_ entry: APODEntry) -> some View {
    let bottomBar = Button {
      withAnimation { detailsShown.toggle() }
      maybeRequestReview(because: .detailsViewed, delay: .seconds(2))
    } label: {
      titleView(for: entry)
    }
    .foregroundColor(.primary)
    .accessibilityHint("Show details")

    switch entry.asset {
    case let .youtubeVideo(id: id, _):
      VStack {
        YouTubePlayer(videoId: id)
        bottomBar
      }

    default:
      ZStack(alignment: .leading) {
        let image = entry.loadImage()
        Group {
          if let image = image {
            ZoomableScrollView {
              Image(uiImage: image)
            }
          } else {
            APODEntryView.failureImage.flexibleFrame()
          }
        }.onTapGesture { withAnimation { titleShown.toggle() } }

        VStack(alignment: .leading) {
          Spacer()
          if titleShown {
            bottomBar
          }
        }
      }
    }
  }

  @ViewBuilder
  var mainBody: some View {
    switch viewModel.currentEntry {
    case .loading:
      VStack(alignment: .leading) {
        ProgressView()
          .colorScheme(.dark)
          .flexibleFrame()

        titleView(for: .placeholder).redacted(reason: .placeholder)
      }

    case .loaded(.failure(let error)):
      VStack(alignment: .leading) {
        APODEntryView.failureImage.flexibleFrame()

        titleView(date: nil, title: "Couldn’t load image", copyright: error.localizedDescription)
      }

    case .loaded(.success(let entry)):
      entryBody(entry)
        .statusBar(hidden: !titleShown)
        .sheet(isPresented: $detailsShown) {
          NavigationView {
            detailsSheet(entry)
          }
        }
        .userActivity(Constants.userActivityType, element: entry.webURL) {
          $1.webpageURL = $0
        }
    }
  }

  var body: some View {
    mainBody
      .onContinueUserActivity(Constants.userActivityType) { _ in
        maybeRequestReview(because: .continuedUserActivity, delay: .seconds(2))
      }
      // Reload whenever the app is foregrounded, and at first launch.
      .onAppear { viewModel.reload() }
      .onChange(of: scenePhase) {
        if $0 == .active {
          viewModel.reload()
        }
      }
      .onOpenURL { url in
        if url == Constants.widgetURL {
          print("Opened from widget")
          maybeRequestReview(because: .openedFromWidget, delay: .seconds(2))
        }
      }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .previewLayout(.fixed(width: 300, height: 400))
  }
}
