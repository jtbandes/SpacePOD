//
//  Utilities.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation
import Combine

infix operator ??=
public func ??=<T>(lhs: inout T?, rhs: @autoclosure () -> T?) {
  lhs = lhs ?? rhs()
}

public func with<T>(_ arg: T, _ body: (inout T) -> Void) -> T {
  var result = arg
  body(&result)
  return result
}

public enum APODErrors: Error {
  case invalidDate(String)
  case invalidURL(String)
}

public extension Optional {
  func orThrow(_ error: Error) throws -> Wrapped {
    if let self = self {
      return self
    }
    throw error
  }

  func orFatalError(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) -> Wrapped {
    if let self = self {
      return self
    }
    fatalError(message(), file: file, line: line)
  }
}

public extension DateComponents {
  init(YMDString string: String) throws {
    let components = string.split(separator: "-")
    guard components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) else {
      throw APODErrors.invalidDate(string)
    }
    self = DateComponents(year: year, month: month, day: day)
  }
}

public enum BinarySearchResult<T> {
  case present(index: T)
  case absent(insertionIndex: T)
}

public extension RangeReplaceableCollection where Element: Comparable {
  func binarySearch(_ element: Element) -> BinarySearchResult<Index> {
    var low = startIndex
    var high = endIndex
    while low < high {
      let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
      if element == self[mid] {
        return .present(index: mid)
      } else if element < self[mid] {
        high = mid
      } else {
        low = index(after: mid)
      }
    }
    return .absent(insertionIndex: low)
  }
}

public extension URLSession {
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

