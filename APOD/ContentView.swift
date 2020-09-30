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
  @State var detailsShown = true

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
        if let image = entry.loadImage() {
          ZoomableScrollView {
            Image(uiImage: image)
          }
        } else {
          APODEntryView.failureImage
        }

        VStack(alignment: .leading) {
          Spacer()
          if detailsShown {
            Group {
              if let title = entry.title {
                Text(title).font(.system(.headline))
              }
              if let copyright = entry.copyright {
                Text(copyright).font(.system(.subheadline))
              }
            }.transition(.move(edge: .bottom))
          }
        }
      }.onTapGesture {
        withAnimation {
          detailsShown.toggle()
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
