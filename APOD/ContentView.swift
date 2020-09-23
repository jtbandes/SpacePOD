//
//  ContentView.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import SwiftUI
import Combine

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

enum Loading<T> {
  case notLoading
  case loading
  case loaded(T)
}

class ViewModel: ObservableObject {
  @Published var currentEntry: Loading<Result<APODEntry, Error>> = .notLoading

  private var _cancellable: AnyCancellable?

  func startLoad() {
    currentEntry = .loading
    _cancellable?.cancel()
    _cancellable = APODClient.shared.loadLatestImage().sinkResult {
      self.currentEntry = .loaded($0)
    }
  }
}

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()

  var body: some View {
    Button("Load latest") {
      viewModel.startLoad()
    }
    switch viewModel.currentEntry {
    case .notLoading: Group {}
    case .loading: ProgressView("Loading")
    case .loaded(.failure(let err)):
      Text(verbatim: "Error: \(err as Any)")
    case .loaded(.success(let val)):
      Text(verbatim: "Loaded: \(val.remoteImageURL as Any)")
//    default: Group {}
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().previewLayout(.fixed(width: 200, height: 200))
  }
}
