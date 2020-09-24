//
//  YearMonthDay.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation

let TIME_ZONE_LA = TimeZone(identifier: "America/Los_Angeles")!

public struct YearMonthDay: LosslessStringConvertible {
  let year: Int
  let month: Int
  let day: Int

  public var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  public func asDate() -> Date? {
    guard let date = Calendar.current.date(from: DateComponents(timeZone: TIME_ZONE_LA, year: year, month: month, day: day))
    else {
      return nil
    }
    return date
  }

  var isCurrent: Bool {
    guard let date = asDate() else {
      return false
    }
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: "en_US")
    calendar.timeZone = TIME_ZONE_LA
    return calendar.isDateInToday(date)
  }

  public init?(_ stringValue: String) {
    let components = stringValue.split(separator: "-")
    guard components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) else {
      return nil
    }
    self.year = year
    self.month = month
    self.day = day
  }
}

extension YearMonthDay: Codable {
  public init(from decoder: Decoder) throws {
    let string = try decoder.singleValueContainer().decode(String.self)
    if let date = YearMonthDay(string) {
      self = date
    } else {
      throw APODErrors.invalidDate(string)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var encoder = encoder.singleValueContainer()
    try encoder.encode(description)
  }
}

extension YearMonthDay: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(year)
    hasher.combine(month)
    hasher.combine(day)
  }
}

extension YearMonthDay: Comparable {
  public static func ==(lhs: YearMonthDay, rhs: YearMonthDay) -> Bool {
    return (lhs.year, lhs.month, lhs.day) == (rhs.year, rhs.month, rhs.day)
  }
  public static func <(lhs: YearMonthDay, rhs: YearMonthDay) -> Bool {
    return (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }
}
