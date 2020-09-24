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
    APODEntryView(entry: viewModel.currentEntry)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().previewLayout(.fixed(width: 300, height: 400))
  }
}
