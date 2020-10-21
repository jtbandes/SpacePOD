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

let youtubeRegex = try! NSRegularExpression(pattern: #"://.*youtube\.com/embed/([^/?#]+)"#)

public enum Asset {
  case image(URL)
  case youtubeVideo(id: String, url: URL)
  case unknown(URL)

  init(mediaType: String, url: URL) {
    switch mediaType {
    case "image":
      self = .image(url)

    case "video":
      let str = url.absoluteString
      if let match = youtubeRegex.firstMatch(in: str, range: NSRange(str.startIndex..<str.endIndex, in: str)),
         let range = Range(match.range(at: 1), in: str) {
        self = .youtubeVideo(id: String(str[range]), url: url)
      } else {
        self = .unknown(url)
      }

    default:
      self = .unknown(url)
    }
  }

  var imageOrThumbnailURL: Result<URL, Error> {
    switch self {
    case .image(let url):
      return .success(url)

    case .youtubeVideo(let id, _):
      // https://stackoverflow.com/q/2068344/23649
      return URL(string: "https://img.youtube.com/vi/\(id)/0.jpg")
        .asResult(ifNil: APODErrors.invalidYouTubeVideo(id))

    case .unknown:
      return .failure(APODErrors.unsupportedAsset)
    }
  }
}

public class APODEntry: Codable {
  private let rawEntry: RawAPODEntry

  public var date: YearMonthDay { rawEntry.date }
  public var title: String? { rawEntry.title }
  public var copyright: String? { rawEntry.copyright }
  public var explanation: String? { rawEntry.explanation }

  public let asset: Asset
  public let localDataURL: URL
  public let localImageURL: URL

  var PREVIEW_overrideImage: UIImage?
  private var _loadedImage: UIImage?
  public func loadImage(decode: Bool) -> UIImage? {
    _loadedImage = _loadedImage ?? PREVIEW_overrideImage
    if _loadedImage == nil {
      _loadedImage = UIImage(contentsOfFile: localImageURL.path)
      if decode {
        _loadedImage = _loadedImage?.decoded()
      }
    }
    return _loadedImage
  }

  public required init(from decoder: Decoder) throws {
    rawEntry = try RawAPODEntry(from: decoder)
    localDataURL = CACHE_URL.appendingPathComponent(rawEntry.date.description).appendingPathExtension(DATA_PATH_EXTENSION)
    localImageURL = CACHE_URL.appendingPathComponent(rawEntry.date.description)

    let mediaURL: URL
    if let hdurl = rawEntry.hdurl {
      mediaURL = hdurl
    } else if let url = rawEntry.url {
      mediaURL = url
    } else {
      throw APODErrors.missingURL
    }

    asset = Asset(mediaType: rawEntry.mediaType, url: mediaURL)
  }

  public func encode(to encoder: Encoder) throws {
    try rawEntry.encode(to: encoder)
  }

  private init(rawEntry: RawAPODEntry, asset: Asset, localDataURL: URL, localImageURL: URL) {
    self.rawEntry = rawEntry
    self.asset = asset
    self.localDataURL = localDataURL
    self.localImageURL = localImageURL
  }


  public static let placeholder: APODEntry = APODEntry(rawEntry: RawAPODEntry(date: YearMonthDay.today, hdurl: nil, url: nil, title: "Example", copyright: "Example copyright", explanation: nil, mediaType: "blah"), asset: .unknown(URL(fileURLWithPath: "/dev/null")), localDataURL: URL(fileURLWithPath: "/dev/null"), localImageURL: URL(fileURLWithPath: "/dev/null"))
}

struct RawAPODEntry: Codable {
  var date: YearMonthDay
  var hdurl: URL?
  var url: URL?
  var title: String?
  var copyright: String?
  var explanation: String?
  var mediaType: String

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
    return Result.success(entry).publisher.eraseToAnyPublisher()
  }

  DBG("Downloading image for \(entry.date)")
  return entry.asset.imageOrThumbnailURL.publisher
    .flatMap(URLSession.shared.downloadTaskPublisher(for:))
    .tryMap { url in
      // Ensure the image is parseable before saving it in the cache
      guard UIImage(contentsOfFile: url.path) != nil else {
        throw APODErrors.invalidImage
      }
      DBG("Trying to move \(url) to \(entry.localImageURL)")
      do {
        try FileManager.default.moveItem(at: url, to: entry.localImageURL)
      } catch {
        if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
          // This race should be rare in practice, but happens frequently during development, when a new build
          // is installed in the simulator, and the app and extension both try to fill the cache at the same time.
          DBG("Image already cached for \(entry.date), continuing")
          return entry
        }
        throw error
      }
      DBG("Moved downloaded file!")
      return entry
    }
    .eraseToAnyPublisher()
}

public class APODClient {

  public static let shared = APODClient()

  private var _cache = SortedDictionary<YearMonthDay, APODEntry>()

  #if DEBUG
  public func debug_clearCache() {
    try? FileManager.default.removeItem(at: CACHE_URL)
  }
  #endif

  private init() {
    do {
      try FileManager.default.createDirectory(at: CACHE_URL, withIntermediateDirectories: true)
      for url in try FileManager.default.contentsOfDirectory(at: CACHE_URL, includingPropertiesForKeys: nil) where url.pathExtension == DATA_PATH_EXTENSION {
        do {
          let data = try Data(contentsOf: url)
          let entry = try JSONDecoder().decode(APODEntry.self, from: data)

          // Delete entries older than 2 days
          if let date = entry.date.asDate(), date.timeIntervalSinceNow < -2*24*60*60 {
            do {
              try FileManager.default.removeItem(at: url)
              try FileManager.default.removeItem(at: entry.localImageURL)
              print("Removed old data for \(entry.date)")
            } catch {
              print("Error removing old data for \(entry.date): \(error)")
            }
          }

          if (try? entry.localImageURL.checkResourceIsReachable()) ?? false {
            _cache[entry.date] = entry
          }
        } catch {
          print("Invalid cache entry: \(error) \(url)")
        }
      }
      DBG("There are \(_cache.count) cached images: \(_cache)")
    }
    catch let error {
      print("Error loading cache: \(error)")
    }
  }

  public func loadLatestImage() -> AnyPublisher<APODEntry, Error> {
    if let lastCached = _cache.last?.value, lastCached.date.isCurrent {
      DBG("Loaded \(lastCached.date) from cache")
      return Result.success(lastCached).publisher.eraseToAnyPublisher()
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
        DBG("Got response! \(response)")
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
