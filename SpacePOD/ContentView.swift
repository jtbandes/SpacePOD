import SwiftUI
import Combine
import SpacePODShared
import WidgetKit
import UniformTypeIdentifiers

class ViewModel: ObservableObject {
  @Published var currentEntry: Loading<Result<APODEntry, Error>> = .loading

  private var cancellable: AnyCancellable?

  init() {
    cancellable = APODClient.shared.loadLatestImage().sinkResult { [unowned self] in
      WidgetCenter.shared.reloadAllTimelines()
      self.currentEntry = .loaded($0)
    }
  }
}

/// We present the UIActivityViewController imperatively rather than wrapping it with UIViewControllerRepresentable
/// because SwiftUI doesn't display it properly (full sheet instead of half sheet on iPhone) and the interactive swipe-to-dismiss
/// causes the `isPresented` binding to immediately become false, which suddenly removes the view controller.
func presentShareSheet(_ entry: APODEntry, _ image: UIImage) {
  guard let visibleViewController = UIApplication.shared.visibleViewController else {
    print("No view controller from which to present share sheet")
    return
  }

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
  let tmpFile = tmpDir.appendingPathComponent(filename)
  do {
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    try FileManager.default.linkItem(at: entry.localImageURL, to: tmpFile)

    activityVC = UIActivityViewController(activityItems: [tmpFile], applicationActivities: nil)
  } catch {
    print("Unable to create temporary file: \(error)")
    return
  }

  activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
    do {
      try FileManager.default.removeItem(at: tmpFile)
    } catch {
      print("Unable to remove temporary file: \(error)")
    }
  }
  visibleViewController.present(activityVC, animated: true)
}

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()
  @State var titleShown = true
  @State var detailsShown = false
  @State var shareSheetShown = false
  @State var urlForWebView: URL?

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
    ScrollView {
      VStack(alignment: .leading) {
        if let title = entry.title {
          Text(title).font(Font.system(.title).weight(.heavy))
        }
        if let copyright = entry.copyright {
          Text(copyright).font(.system(.callout)).foregroundColor(.secondary)
        }
        Spacer().frame(height: 24)
        if let explanation = entry.explanation {
          Text(explanation).font(.system(.body, design: .serif))
        } else {
          Text("No details available").foregroundColor(.secondary).flexibleFrame(alignment: .center)
        }
      }.padding()
      .flexibleFrame(alignment: .topLeading)
    }
  }

  @ViewBuilder
  func entryBody(_ entry: APODEntry) -> some View {
    let title = Button {
      withAnimation { detailsShown.toggle() }
    } label: {
      titleView(for: entry)
    }
    .foregroundColor(.primary)
    .accessibilityHint("Show details")

    switch entry.asset {
    case let .youtubeVideo(id: id, _):
      VStack {
        YouTubePlayer(videoId: id)
        title
      }

    default:
      ZStack(alignment: .leading) {
        let image = entry.loadImage()
        Group {
          if let image = image{
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
            HStack {
              title
              if let image = image {
                Button(action: { presentShareSheet(entry, image) }) {
                  Image(systemName: "square.and.arrow.up").imageScale(.large).padding()
                }
              }
            }
          }
        }
      }
    }
  }

  var body: some View {
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
              }
          }
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
