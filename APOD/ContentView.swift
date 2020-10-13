//
//  ContentView.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import SwiftUI
import Combine
import APODShared

extension Publisher {
  func sinkResult(_ receiveResult: @escaping (Result<Output, Failure>) -> Void) -> AnyCancellable {
    return sink {
      switch $0 {
      case .failure(let err):
        receiveResult(.failure(err))
      case .finished:
        print("Finished, ignoring")
      }
    } receiveValue: {
      receiveResult(.success($0))
    }
  }
}

class ViewModel: ObservableObject {
  @Published var currentEntry: Loading<Result<APODEntry, Error>> = .notLoading

  private var cancellable: AnyCancellable?

  init() {
    currentEntry = .loading
    cancellable = APODClient.shared.loadLatestImage().sinkResult { [unowned self] in
      self.currentEntry = .loaded($0)
    }
  }
}

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()
  @State var titleShown = true
  @State var detailsShown = false

  @ViewBuilder
  func titleContent(_ entry: APODEntry) -> some View {
    VStack(alignment: .leading) {
      if let date = entry.date.asDate() {
        Text(date, style: .date).font(.system(.caption)).foregroundColor(.secondary)
      }
      if let title = entry.title {
        Text(title).font(.system(.headline))
      }
      if let copyright = entry.copyright {
        Text(copyright).font(.system(.subheadline)).foregroundColor(.secondary)
      }
    }
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

    case .notLoading:
      Text("Not loading")

    case .loading:
      Text("Loading")

    case .loaded(.failure(let error)):
      Text(verbatim: "Error: \(error)")

    case .loaded(.success(let entry)):
      ZStack(alignment: .leading) {
        Group {
          if let image = entry.loadImage() {
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
              titleContent(entry)
                .flexibleFrame(.horizontal, alignment: .leading)
                .padding()
                .contentShape(Rectangle())
                .shadow(color: .black, radius: 2, x: 0.0, y: 0.0)
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
