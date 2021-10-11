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
private let VIMEO_OEMBED_API_URL = URLComponents(string: "https://vimeo.com/api/oembed.json")!
private let DATA_PATH_EXTENSION = "json"

private let CACHE_URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.spaceAppGroupID)!.appendingPathComponent("cache")

let youtubeRegex = try! NSRegularExpression(pattern: #"://.*youtube\.com/embed/([^/?#]+)"#)
let vimeoRegex = try! NSRegularExpression(pattern: #"://.*vimeo\.com/video/([^/?#]+)"#)

// https://developer.vimeo.com/api/oembed/videos
struct VimeoOEmbedResponse: Decodable {
  var thumbnailURL: URL
  enum CodingKeys: String, CodingKey {
    case thumbnailURL = "thumbnail_url"
  }
}

public enum Asset {
  case image(URL)
  case vimeoVideo(id: String, url: URL)
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
      } else if
        let match = vimeoRegex.firstMatch(in: str, range: NSRange(str.startIndex..<str.endIndex, in: str)),
        let range = Range(match.range(at: 1), in: str) {
        self = .vimeoVideo(id: String(str[range]), url: url)
      } else {
        self = .unknown(url)
      }

    default:
      self = .unknown(url)
    }
  }

  func downloadImageOrThumbnail() -> AnyPublisher<URL, Error> {
    switch self {
    case .image(let url):
      return URLSession.shared.downloadTaskPublisher(for: url)

    case .youtubeVideo(let id, _):
      // https://stackoverflow.com/q/2068344/23649
      return URL(string: "https://img.youtube.com/vi/\(id)/0.jpg")
        .asResult(ifNil: APODErrors.invalidYouTubeVideo(id))
        .publisher
        .flatMap(URLSession.shared.downloadTaskPublisher(for:))
        .eraseToAnyPublisher()

    case .vimeoVideo(let id, let url):
      var components = VIMEO_OEMBED_API_URL
      components.queryItems[withDefault: []]
        .append(contentsOf: [
          URLQueryItem(name: "url", value: url.absoluteString),
          URLQueryItem(name: "width", value: "2000"),
          URLQueryItem(name: "height", value: "2000"),
        ])
      return components.url
        .asResult(ifNil: APODErrors.invalidVimeoVideo(id) as Error)
        .publisher
        .flatMap { url in
          URLSession.shared.dataTaskPublisher(for: url).mapError { $0 }
        }
        .tryMap { (responseData, response) -> VimeoOEmbedResponse in
          DBG("Got response! \(response)")
          guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
          }
          guard response.statusCode == 200 else {
            throw APODErrors.failureResponse(statusCode: response.statusCode)
          }
          return try JSONDecoder().decode(VimeoOEmbedResponse.self, from: responseData)
        }
        .flatMap { response in
          URLSession.shared.downloadTaskPublisher(for: response.thumbnailURL)
        }
        .eraseToAnyPublisher()

    case .unknown:
      return Result.failure(APODErrors.unsupportedAsset).publisher.eraseToAnyPublisher()
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

  /// JSON data path relative to `CACHE_URL`.
  public let dataFilename: String
  /// Image path relative to `CACHE_URL`.
  public let imageFilename: String

  var PREVIEW_overrideImage: UIImage?
  private var _loadedImage: UIImage?
  public func loadImage() -> UIImage? {
    _loadedImage = _loadedImage ?? PREVIEW_overrideImage ?? (try? NSFileCoordinator().coordinate(readingItemAt: CACHE_URL) { cacheURL in
      UIImage(contentsOfFile: cacheURL.appendingPathComponent(imageFilename).path)
    })
    return _loadedImage
  }

  public var webURL: URL? {
    let dateStr = String(format: "%02d%02d%02d", date.year % 100, date.month, date.day)
    return URL(string: "https://apod.nasa.gov/apod/ap\(dateStr).html")
  }

  public required init(from decoder: Decoder) throws {
    rawEntry = try RawAPODEntry(from: decoder)
    dataFilename = "\(rawEntry.date.description).\(DATA_PATH_EXTENSION)"
    imageFilename = rawEntry.date.description

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

  private init(rawEntry: RawAPODEntry, asset: Asset, dataFilename: String, imageFilename: String) {
    self.rawEntry = rawEntry
    self.asset = asset
    self.dataFilename = dataFilename
    self.imageFilename = imageFilename
  }


  public static let placeholder: APODEntry = APODEntry(rawEntry: RawAPODEntry(date: YearMonthDay.today, hdurl: nil, url: nil, title: "Example", copyright: "Example copyright", explanation: nil, mediaType: "blah"), asset: .unknown(URL(fileURLWithPath: "/dev/null")), dataFilename: "placeholder", imageFilename: "placeholder")

  /// The earliest expected date that the next entry will be available from the server.
  static func nextExpectedEntryDate(after entry: APODEntry) -> Date? {
    return entry.date.nextDate(in: .losAngeles)
  }

  public func coordinateReadingImage(byAccessor block: (URL) throws -> Void) throws {
    try NSFileCoordinator().coordinate(readingItemAt: CACHE_URL) { cacheURL in
      try block(cacheURL.appendingPathComponent(self.imageFilename))
    }
  }
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

public class APODClient {

  public static let shared = APODClient()

  private var _cache: (data: SortedDictionary<YearMonthDay, APODEntry>, loadedAt: Date)? = nil

  #if DEBUG
  public func debug_clearCache() {
    try? NSFileCoordinator().coordinate(writingItemAt: CACHE_URL, options: .forDeleting) { cacheURL in
      try FileManager.default.removeItem(at: CACHE_URL)
    }
  }
  #endif

  private init() {
    #if DEBUG && targetEnvironment(simulator)
    print("Cache URL: \(CACHE_URL.path)")
    #endif
    reloadCache()
  }

  // Rather than updating the cache with any new entries from disk, we just reload it completely.
  // This logic is simpler to follow and to wrap in a coordinated access, which avoids potential races
  // between processes (extension & main app) where one deletes entries from the cache while the other is loading it.
  // This shouldn't be too expensive because we expect the number of items in the cache to be small
  // (2–3, since we delete older entries).
  func reloadCache() {
    if let loadedAt = _cache?.loadedAt,
       let lastUpdatedAt = UserDefaults.spaceAppGroup.lastAPODCacheDate,
       loadedAt >= lastUpdatedAt {
      // The cache is up to date.
      return
    }

    do {
      try NSFileCoordinator().coordinate(writingItemAt: CACHE_URL) { cacheURL in
        _cache = (try Self.loadAndCleanCache(coordinatedAt: cacheURL), loadedAt: Date())
      }
      if let cache = _cache {
        DBG("There are \(cache.data.count) cached images: \(cache.data)")
      }
    }
    catch {
      print("Error loading cache: \(error)")
    }
  }

  static func loadAndCleanCache(coordinatedAt cacheURL: URL) throws -> SortedDictionary<YearMonthDay, APODEntry> {
    var result = SortedDictionary<YearMonthDay, APODEntry>()
    try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    let urls = Set(try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil))
    for url in urls where url.pathExtension == DATA_PATH_EXTENSION {
      do {
        let entry = try JSONDecoder().decode(APODEntry.self, from: Data(contentsOf: url))

        // Delete entries older than 2 days
        if let date = entry.date.asDate(), date.timeIntervalSinceNow < -2*24*60*60 {
          do {
            try FileManager.default.removeItem(at: url)
            try FileManager.default.removeItem(at: cacheURL.appendingPathComponent(entry.imageFilename))
            print("Removed old data for \(entry.date)")
          } catch {
            print("Error removing old data for \(entry.date): \(error)")
          }
        } else if urls.contains(cacheURL.appendingPathComponent(entry.imageFilename)) {
          result[entry.date] = entry
        } else {
          throw APODErrors.invalidImage
        }
      } catch {
        print("Invalid cache entry: \(error) \(url)")
      }
    }
    return result
  }

  public func loadLatestImage() -> AnyPublisher<APODEntry, Error> {
    reloadCache()

    // Return the latest cached entry if it's not stale.
    if let lastCached = _cache?.data.last?.value {
      // Would we expect to find a new entry if we queried the server now?
      let newEntryExpected = APODEntry.nextExpectedEntryDate(after: lastCached)
        .map { $0.timeIntervalSinceNow <= 0 } ?? true

      // Has it been an hour since we last queried the server?
      let lastCacheDate = UserDefaults.spaceAppGroup.lastAPODCacheDate
      let cacheIsStale = lastCacheDate.map { -$0.timeIntervalSinceNow > 60*60 } ?? true

      if newEntryExpected && cacheIsStale {
        DBG("Cache is stale: \(lastCacheDate?.description ?? "never cached")")
      } else {
        DBG("Loaded \(lastCached.date) from cache")
        return Result.success(lastCached).publisher.eraseToAnyPublisher()
      }
    }

    var components = API_URL
    components.queryItems[withDefault: []]
      .append(contentsOf: [
        // Rather than requesting the current date, request a range starting from yesterday to avoid "no data available"
        // https://github.com/nasa/apod-api/issues/48
        URLQueryItem(name: "start_date", value: (YearMonthDay.yesterday ?? YearMonthDay.today).description),
        // Including end_date returns 400 when end_date is after today
      ])

    guard let requestURL = components.url else {
      return Result.failure(APODErrors.missingURL).publisher.eraseToAnyPublisher()
    }

    return URLSession.shared.dataTaskPublisher(for: requestURL)
    // Download and parse entry
      .tryMap { (responseData, response) -> APODEntry in
        DBG("Got response! \(response)")
        guard let response = response as? HTTPURLResponse else {
          throw URLError(.badServerResponse)
        }
        guard response.statusCode == 200 else {
          throw APODErrors.failureResponse(statusCode: response.statusCode)
        }

        let entries = try JSONDecoder().decode([APODEntry].self, from: responseData)
        guard let entry = entries.last else {
          throw APODErrors.emptyResponse
        }
        return entry
      }
    // Download image or video thumbnail
      .flatMap { entry in
        entry.asset.downloadImageOrThumbnail()
          .map { imageURL in (imageURL, entry) }
      }
    // Save to cache
      .tryMap { (imageURL, entry) -> APODEntry in
        let entryData = try JSONEncoder().encode(entry)
        guard UIImage(contentsOfFile: imageURL.path) != nil else {
          throw APODErrors.invalidImage
        }
        DBG("Trying to save \(entry) to cache")
        try NSFileCoordinator().coordinate(writingItemAt: CACHE_URL) { cacheURL in
          let imageDestURL = cacheURL.appendingPathComponent(entry.imageFilename)
          if (try? imageDestURL.checkResourceIsReachable()) ?? false {
            // This race should be rare in practice, but happens frequently during development, when a new build
            // is installed in the simulator, and the app and extension both try to fill the cache at the same time.
            DBG("Image already cached for \(entry.date), continuing")
          } else {
            try FileManager.default.moveItem(at: imageURL, to: imageDestURL)
          }

          try entryData.write(to: cacheURL.appendingPathComponent(entry.dataFilename))

          UserDefaults.spaceAppGroup.lastAPODCacheDate = Date()
        }
        DBG("Saved!")
        return entry
      }
      .receive(on: DispatchQueue.main)
      .map { [weak self] entry in
        self?.reloadCache()
        return entry
      }
      .eraseToAnyPublisher()
  }

}
