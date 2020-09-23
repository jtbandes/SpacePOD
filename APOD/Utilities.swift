//
//  Utilities.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation

enum APODErrors: Error {
  case invalidDate(String)
  case invalidURL(String)
}

extension Optional {
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

extension DateComponents {
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
