//
//  APODManager.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation
import Combine
import APODShared

private let API_URL = URLComponents(string: "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY")!

private let CACHE_URL = URL(
  fileURLWithPath: "cache", relativeTo:
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.APOD")!)

struct APODEntry: Decodable {
  var date: YearMonthDay
  var remoteImageURL: URL
  var copyright: String?

  var localImageURL: URL {
    CACHE_URL.appendingPathComponent(date.description)
  }

  enum CodingKeys: String, CodingKey {
    case copyright
    case date
    case explanation
    case hdurl
    case url
    case media_type
    case service_version
    case title
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = try container.decode(YearMonthDay.self, forKey: .date)
    let urlString = try container.decodeIfPresent(String.self, forKey: .hdurl) ?? container.decode(String.self, forKey: .url)
    remoteImageURL = try URL(string: urlString).orThrow(APODErrors.invalidURL(urlString))
    copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
  }
}

struct APODCacheEntry {
  let date: YearMonthDay
  let localImageURL: URL
}

class APODClient {

  static let shared = APODClient()

  private var _cachedImages = SortedDictionary<YearMonthDay, APODCacheEntry>()

  private init() {
    do {
      try FileManager.default.createDirectory(at: CACHE_URL, withIntermediateDirectories: true)

      for url in try FileManager.default.contentsOfDirectory(at: CACHE_URL, includingPropertiesForKeys: nil) {
        let filename = url.deletingPathExtension().lastPathComponent
        if let date = YearMonthDay(filename) {
          _cachedImages[date] = APODCacheEntry(date: date, localImageURL: url)
        } else {
          print("Invalid filename: \(url)")
        }
      }
      print("There are \(_cachedImages.count) cached images: \(_cachedImages)")
    }
    catch let error {
      print("Error loading cache: \(error)")
    }
  }

  private func _loadRemoteImageIntoCache(_ entry: APODEntry) -> AnyPublisher<APODEntry, Error> {
    if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
      return CurrentValueSubject<APODEntry, Error>(entry).eraseToAnyPublisher()
    }

    return URLSession.shared.downloadTaskPublisher(for: entry.remoteImageURL)
      .tryMap { url in
        try FileManager.default.moveItem(at: url, to: entry.localImageURL)
        print("Moved downloaded file!")
        return entry
      }
      .eraseToAnyPublisher()
  }

  func loadLatestImage() -> AnyPublisher<APODCacheEntry, Error> {
    let components = API_URL

    if let lastCached = _cachedImages.last?.value, lastCached.date.isCurrent {
      print("Loaded \(lastCached.date) from cache")
      return CurrentValueSubject(lastCached).eraseToAnyPublisher()
    }

    return URLSession.shared.dataTaskPublisher(for: components.url.orFatalError("Failed to build API URL"))
      .tryMap() { (data, response) in
        print("Got response! \(response)")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
          throw URLError(.badServerResponse)
        }
        return data
      }
      .decode(type: APODEntry.self, decoder: JSONDecoder())
      .flatMap(_loadRemoteImageIntoCache)
      .receive(on: DispatchQueue.main)
      .map { [weak self] in
        let cacheEntry = APODCacheEntry(date: $0.date, localImageURL: $0.localImageURL)
        self?._cachedImages[$0.date] = cacheEntry
        return cacheEntry
      }
      .eraseToAnyPublisher()
  }

}
