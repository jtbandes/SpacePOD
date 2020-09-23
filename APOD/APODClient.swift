//
//  APODManager.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation
import Combine

private let API_URL = URLComponents(string: "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY")!

struct APODEntry: Decodable {
  var date: DateComponents
  var remoteImageURL: URL
  var copyright: String?

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
    date = try DateComponents(YMDString: container.decode(String.self, forKey: .date))
    let urlString = try container.decodeIfPresent(String.self, forKey: .hdurl) ?? container.decode(String.self, forKey: .url)
    remoteImageURL = try URL(string: urlString).orThrow(APODErrors.invalidURL(urlString))
    copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
  }
}



class APODClient {

  static let shared = APODClient()

  private let _cacheURL = URL(
    fileURLWithPath: "images", relativeTo:
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.APOD")!)

  private var _cachedImages: [DateComponents : URL] = [:]

  private let _urlSession = URLSession(configuration: .default)

  private init() {
    do {
      try FileManager.default.createDirectory(at: _cacheURL, withIntermediateDirectories: true)
      for url in try FileManager.default.contentsOfDirectory(at: _cacheURL, includingPropertiesForKeys: nil) {
        let filename = url.deletingPathExtension().lastPathComponent
        if let components = try? DateComponents(YMDString: filename) {
          _cachedImages[components] = url
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

  func loadLatestImage() -> AnyPublisher<APODEntry, Error> {
    let components = API_URL

    return _urlSession.dataTaskPublisher(for: components.url.orFatalError("Failed to build API URL"))
      .tryMap() { (data, response) in
        print("Got response! \(response)")
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
          throw URLError(.badServerResponse)
        }
        return data
      }
      .decode(type: APODEntry.self, decoder: JSONDecoder())
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

}
