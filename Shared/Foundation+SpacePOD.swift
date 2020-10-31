import Foundation
import Combine

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
    $0.setLocalizedDateFormatFromTemplate("MMM dd")
  }
}

public extension UserDefaults {
  static var spaceAppGroup = UserDefaults(suiteName: Constants.spaceAppGroupID)!

  var lastAPODCacheDate: Date? {
    get { object(forKey: "lastAPODCacheDate") as? Date }
    set { set(newValue, forKey: "lastAPODCacheDate") }
  }
}
