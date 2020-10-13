//
//  APODManager.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation
import Combine
import UIKit

func getAPIKey() -> String {
  if let key = Bundle(for: APODEntry.self).object(forInfoDictionaryKey: "NASA_API_KEY") as? String, !key.isEmpty {
    return key
  }
  return "DEMO_KEY"
}

private let API_URL = URLComponents(string: "https://api.nasa.gov/planetary/apod?api_key=\(getAPIKey())")!
private let DATA_PATH_EXTENSION = "json"

private let CACHE_URL = URL(
  fileURLWithPath: "cache", relativeTo:
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.APOD")!)

public class APODEntry: Codable {
  private let rawEntry: RawAPODEntry

  public var date: YearMonthDay { rawEntry.date }
  public var title: String? { rawEntry.title }
  public var copyright: String? { rawEntry.copyright }
  public var explanation: String? { rawEntry.explanation }

  public let localDataURL: URL
  public let localImageURL: URL
  public let remoteImageURL: URL

  var PREVIEW_overrideImage: UIImage?
  private var _loadedImage: UIImage?
  public func loadImage() -> UIImage? {
    _loadedImage = _loadedImage ?? PREVIEW_overrideImage ?? UIImage(contentsOfFile: localImageURL.path)?.decoded()
    return _loadedImage
  }

  public required init(from decoder: Decoder) throws {
    rawEntry = try RawAPODEntry(from: decoder)
    localDataURL = CACHE_URL.appendingPathComponent(rawEntry.date.description).appendingPathExtension(DATA_PATH_EXTENSION)
    localImageURL = CACHE_URL.appendingPathComponent(rawEntry.date.description)

    if let hdurl = rawEntry.hdurl {
      remoteImageURL = hdurl
    } else if let url = rawEntry.url {
      remoteImageURL = url
    } else {
      throw APODErrors.missingURL
    }
  }

  public func encode(to encoder: Encoder) throws {
    try rawEntry.encode(to: encoder)
  }
}

struct RawAPODEntry: Codable {
  var date: YearMonthDay
  var hdurl: URL?
  var url: URL?
  var title: String?
  var copyright: String?
  var explanation: String?
  var mediaType: String?

  enum CodingKeys: String, CodingKey {
    case copyright
    case date
    case explanation
    case hdurl
    case url
    case mediaType = "media_type"
    case title
  }
}

func _downloadImageIfNeeded(_ entry: APODEntry) -> AnyPublisher<APODEntry, Error> {
  if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
    return Just(entry).mapError { SR_13638 -> Error in }.eraseToAnyPublisher()
  }

  print("Downloading image for \(entry.date)")
  return URLSession.shared.downloadTaskPublisher(for: entry.remoteImageURL)
    .tryMap { url in
      print("Trying to move \(url) to \(entry.localImageURL)")
      do {
        try FileManager.default.moveItem(at: url, to: entry.localImageURL)
      } catch {
        if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
          // This race should be rare in practice, but happens frequently during development, when a new build
          // is installed in the simulator, and the app and extension both try to fill the cache at the same time.
          print("Image already cached for \(entry.date), continuing")
          return entry
        }
        throw error
      }
      print("Moved downloaded file!")
      return entry
    }
    .eraseToAnyPublisher()
}

public class APODClient {

  public static let shared = APODClient()

  private var _cache = SortedDictionary<YearMonthDay, APODEntry>()

  private init() {
    do {
      try FileManager.default.createDirectory(at: CACHE_URL, withIntermediateDirectories: true)
      for url in try FileManager.default.contentsOfDirectory(at: CACHE_URL, includingPropertiesForKeys: nil) where url.pathExtension == DATA_PATH_EXTENSION {
        do {
          let data = try Data(contentsOf: url)
          let entry = try JSONDecoder().decode(APODEntry.self, from: data)
          if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
            _cache[entry.date] = entry
          }
        } catch {
          print("Invalid cache entry: \(error) \(url)")
        }
      }
      print("There are \(_cache.count) cached images: \(_cache)")
    }
    catch let error {
      print("Error loading cache: \(error)")
    }
  }

  public func loadLatestImage() -> AnyPublisher<APODEntry, Error> {
    if let lastCached = _cache.last?.value, lastCached.date.isCurrent {
      print("Loaded \(lastCached.date) from cache")
      return Just(lastCached).mapError { SR_13638 -> Error in }.eraseToAnyPublisher()
    }

    var components = API_URL
    components.queryItems[withDefault: []]
      .append(contentsOf: [
        // Rather than requesting the current date, request a range starting from yesterday to avoid "no data available"
        // https://github.com/nasa/apod-api/issues/48
        URLQueryItem(name: "start_date", value: (YearMonthDay.yesterday ?? YearMonthDay.today).description),
        // Including end_date returns 400 when end_date is after today
      ])

    return URLSession.shared.dataTaskPublisher(for: components.url.orFatalError("Failed to build API URL"))
      .tryMap() { (data, response) in
        print("Got response! \(response)")
        guard let response = response as? HTTPURLResponse else {
          throw URLError(.badServerResponse)
        }
        guard response.statusCode == 200 else {
          throw APODErrors.failureResponse(statusCode: response.statusCode)
        }

        let entries = try JSONDecoder().decode([APODEntry].self, from: data)
        guard let entry = entries.last else {
          throw APODErrors.emptyResponse
        }
        try JSONEncoder().encode(entry).write(to: entry.localDataURL)
        return entry
      }
      .flatMap(_downloadImageIfNeeded)
      .receive(on: DispatchQueue.main)
      .map { [weak self] entry in
        self?._cache[entry.date] = entry
        return entry
      }
      .eraseToAnyPublisher()
  }

}
