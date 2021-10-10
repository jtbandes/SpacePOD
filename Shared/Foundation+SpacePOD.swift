import Foundation
import Combine
import UIKit

extension Calendar {
  public static let losAngeles = configure(Calendar(identifier: .gregorian)) {
    $0.locale = Locale(identifier: "en_US")
    $0.timeZone = .losAngeles
  }
}

extension TimeZone {
  public static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
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

extension DateFormatter {
  static let monthDay = configure(DateFormatter()) {
    $0.setLocalizedDateFormatFromTemplate("MMM d")
  }
}

public extension UserDefaults {
  static var spaceAppGroup = UserDefaults(suiteName: Constants.spaceAppGroupID)!

  var lastAPODCacheDate: Date? {
    get { object(forKey: "lastAPODCacheDate") as? Date }
    set { set(newValue, forKey: "lastAPODCacheDate") }
  }
}

extension NSFileCoordinator {
  // Wrapper around the `outError` version of this method, making it `throws`-friendly.
  func coordinate<T>(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], byAccessor reader: (URL) throws -> T) throws -> T {
    var coordinationError: NSError?
    var result: Result<T, Error> = .failure(APODErrors.fileCoordinationFailed)
    coordinate(readingItemAt: url, options: options, error: &coordinationError) { newURL in
      result = Result { try reader(newURL) }
    }
    if let coordinationError = coordinationError { throw coordinationError }
    return try result.get()
  }

  // Wrapper around the `outError` version of this method, making it `throws`-friendly.
  func coordinate<T>(writingItemAt url: URL, options: NSFileCoordinator.WritingOptions = [], byAccessor writer: (URL) throws -> T) throws -> T {
    var coordinationError: NSError?
    var result: Result<T, Error> = .failure(APODErrors.fileCoordinationFailed)
    coordinate(writingItemAt: url, options: options, error: &coordinationError) { newURL in
      result = Result { try writer(newURL) }
    }
    if let coordinationError = coordinationError { throw coordinationError }
    return try result.get()
  }
}
