import SwiftUI
import Combine
import SpacePODShared
import WidgetKit
import YTPlayerView

extension Publisher {
  func sinkResult(_ receiveResult: @escaping (Result<Output, Failure>) -> Void) -> AnyCancellable {
    return sink {
      switch $0 {
      case .failure(let err):
        receiveResult(.failure(err))
      case .finished:
        DBG("Finished, ignoring")
      }
    } receiveValue: {
      receiveResult(.success($0))
    }
  }
}

struct YouTubePlayer: UIViewRepresentable {
  let videoId: String

  func makeCoordinator() -> Coordinator {
    return Coordinator()
  }

  func makeUIView(context: Context) -> YTPlayerView {
    let player = YTPlayerView()
    player.delegate = context.coordinator
    context.coordinator.currentId = videoId
    player.load(withVideoId: videoId, playerVars: ["playsinline": 1])
    return player
  }

  func updateUIView(_ uiView: YTPlayerView, context: Context) {
    // In practice, this is called when dismissing the details sheet, so the id doesn't actually change.
    if context.coordinator.currentId != videoId {
      DBG("Updating video id: \(context.coordinator.currentId ?? "nil") -> \(videoId). This should likely never happen.")
      uiView.cueVideo(byId: videoId, startSeconds: 0)
      context.coordinator.currentId = videoId
    }
  }

  class Coordinator: NSObject, YTPlayerViewDelegate {
    var currentId: String?

    func playerViewPreferredInitialLoading(_ playerView: YTPlayerView) -> UIView? {
      return with(UIActivityIndicatorView()) {
        $0.startAnimating()
      }
    }

    func playerViewPreferredWebViewBackgroundColor(_ playerView: YTPlayerView) -> UIColor {
      return .clear
    }
  }
}

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

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()
  @State var titleShown = true
  @State var detailsShown = false

  func titleView(for entry: APODEntry) -> some View {
    titleView(date: entry.date.asDate(), title: entry.title, copyright: entry.copyright)
  }

  @ViewBuilder
  func titleView(date: Date?, title: String?, copyright: String?) -> some View {
    VStack(alignment: .leading) {
      if let date = date {
        Text(date, style: .date)
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

    case .loaded(.success(let entry)): Group {
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
          Group {
            if let image = entry.loadImage(decode: true) {
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
              title
            }
          }
        }
      }
    }
    .statusBar(hidden: !titleShown)
    .sheet(isPresented: $detailsShown) {
      NavigationView {
        detailsSheet(entry)
          .navigationTitle(entry.date.asDate().map { Text($0, style: .date) } ?? Text(""))
          .navigationBarTitleDisplayMode(.inline)
          .navigationBarItems(trailing: Button("Done") { detailsShown = false })
      }
    }
    } // Group
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .previewLayout(.fixed(width: 300, height: 400))
  }
}
