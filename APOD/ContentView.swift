import SwiftUI
import Combine
import APODShared
import WidgetKit

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
      ZStack(alignment: .leading) {
        ProgressView()
          .colorScheme(.dark)
          .flexibleFrame()

        VStack(alignment: .leading) {
          Spacer()
          titleView(for: .placeholder).redacted(reason: .placeholder)
        }
      }

    case .loaded(.failure(let error)):
      ZStack(alignment: .leading) {
        APODEntryView.failureImage.flexibleFrame()

        VStack(alignment: .leading) {
          Spacer()
          titleView(date: nil, title: "Couldn’t load image", copyright: error.localizedDescription)
        }
      }

    case .loaded(.success(let entry)):
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
            Button {
              withAnimation { detailsShown.toggle() }
            } label: {
              titleView(for: entry)
            }
            .foregroundColor(.primary)
            .accessibilityHint("Show details")
          }
        }
      }.sheet(isPresented: $detailsShown) {
        NavigationView {
          detailsSheet(entry)
            .navigationTitle(entry.date.asDate().map { Text($0, style: .date) } ?? Text(""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { detailsShown = false })
        }
      }.statusBar(hidden: !titleShown)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .previewLayout(.fixed(width: 300, height: 400))
  }
}
