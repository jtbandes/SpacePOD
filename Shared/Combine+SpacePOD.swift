import Combine
import Foundation

extension Publisher {

  /// Attaches a subscriber with closure-based behavior. Rather than separate error and failure closures as with `sink(receiveCompletion:receiveValue:)`, the closure receives a single `Result` containing success or failure information.
  /// ///
  /// - Note: This method assumes that the receiver will only publish a single value.
  public func sinkResult(_ receiveResult: @escaping (Result<Output, Failure>) -> Void) -> AnyCancellable {
    return sink(receiveCompletion: {
      switch $0 {
      case .failure(let err):
        receiveResult(.failure(err))
      case .finished:
        break
      }
    }, receiveValue: {
      receiveResult(.success($0))
    })
  }

}

public extension URLSession {

  /// Returns a publisher that wraps a download task for a given URL. The publisher publishes the file URL when the download completes, or fails if the download fails.
  func downloadTaskPublisher(for url: URL) -> AnyPublisher<URL, Error> {
    let subject = PassthroughSubject<URL, Error>()
    let task = downloadTask(with: url) { (location, response, error) in
      if let error = error {
        subject.send(completion: .failure(error))
        return
      }
      guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
        subject.send(completion: .failure(URLError(.badServerResponse)))
        return
      }
      guard let location = location else {
        subject.send(completion: .failure(URLError(.cannotOpenFile)))
        return
      }
      subject.send(location)
      subject.send(completion: .finished)
    }
    return subject.handleEvents(
      receiveCancel: { task.cancel() },
      receiveRequest: { if $0 > .none { task.resume() } })
      .eraseToAnyPublisher()
  }

}
