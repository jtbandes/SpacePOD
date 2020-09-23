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

class ViewModel: ObservableObject {
  @Published var result: Result<APODEntry, Error>?
  var cancellableSet = Set<AnyCancellable>()

  init() {
    objectWillChange.send()
  }

  func startLoad() {
    APODClient.shared.loadLatestImage().sinkResult { self.result = $0 }.store(in: &cancellableSet)
  }
}

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()

  var body: some View {
    Button("Load latest") {
      viewModel.startLoad()
    }
    switch viewModel.result {
    case .failure(let err):
      Text(verbatim: "Error: \(err as Any)")
    case .success(let val):
      Text(verbatim: "Loaded: \(val.remoteImageURL as Any)")
    default: Group {}
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().previewLayout(.fixed(width: 200, height: 200))
  }
}
