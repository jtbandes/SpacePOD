//
//  YearMonthDay.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation

struct YearMonthDay: LosslessStringConvertible {
  let year: Int
  let month: Int
  let day: Int

  var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  var isCurrent: Bool {
    guard let timeZone = TimeZone(identifier: "America/Los_Angeles"),
          let date = Calendar.current.date(from: DateComponents(timeZone: timeZone, year: year, month: month, day: day))
    else {
      return false
    }
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: "en_US")
    calendar.timeZone = timeZone
    return calendar.isDateInToday(date)
  }

  init?(_ stringValue: String) {
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
  init(from decoder: Decoder) throws {
    let string = try decoder.singleValueContainer().decode(String.self)
    if let date = YearMonthDay(string) {
      self = date
    } else {
      throw APODErrors.invalidDate(string)
    }
  }

  func encode(to encoder: Encoder) throws {
    var encoder = encoder.singleValueContainer()
    try encoder.encode(description)
  }
}

extension YearMonthDay: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(year)
    hasher.combine(month)
    hasher.combine(day)
  }
}

extension YearMonthDay: Comparable {
  static func ==(lhs: YearMonthDay, rhs: YearMonthDay) -> Bool {
    return (lhs.year, lhs.month, lhs.day) == (rhs.year, rhs.month, rhs.day)
  }
  static func <(lhs: YearMonthDay, rhs: YearMonthDay) -> Bool {
    return (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }
}
