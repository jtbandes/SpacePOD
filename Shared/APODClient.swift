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

public class APODEntry: Decodable {
  public var date: YearMonthDay
  var remoteImageURL: URL
  public var copyright: String?
  public var title: String?
  public var explanation: String?

  var localDataURL: URL {
    CACHE_URL.appendingPathComponent(date.description).appendingPathExtension(DATA_PATH_EXTENSION)
  }
  var localImageURL: URL {
    CACHE_URL.appendingPathComponent(date.description)
  }

  var PREVIEW_overrideImage: UIImage?
  private var _loadedImage: UIImage?
  public func loadImage() -> UIImage? {
    _loadedImage = _loadedImage ?? PREVIEW_overrideImage ?? UIImage(contentsOfFile: localImageURL.path)?.decoded()
    return _loadedImage
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

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = try container.decode(YearMonthDay.self, forKey: .date)
    let urlString = try container.decodeIfPresent(String.self, forKey: .hdurl) ?? container.decode(String.self, forKey: .url)
    remoteImageURL = try URL(string: urlString).orThrow(APODErrors.invalidURL(urlString))
    copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
  }
}

func _downloadImageIfNeeded(_ entry: APODEntry) -> AnyPublisher<APODEntry, Error> {
  if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
    return Just(entry).mapError { SR_13638 -> Error in }.eraseToAnyPublisher()
  }

  print("Downloading image for \(entry.date)")
  return URLSession.shared.downloadTaskPublisher(for: entry.remoteImageURL)
    .tryMap { url in
      try FileManager.default.moveItem(at: url, to: entry.localImageURL)
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
      .append(URLQueryItem(name: "date", value: YearMonthDay.current.description))

    return URLSession.shared.dataTaskPublisher(for: components.url.orFatalError("Failed to build API URL"))
      .tryMap() { (data, response) in
        print("Got response! \(response)")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
          throw URLError(.badServerResponse)
        }

        let entry = try JSONDecoder().decode(APODEntry.self, from: data)
        try data.write(to: entry.localDataURL)
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
