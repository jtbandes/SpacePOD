import WidgetKit
import SwiftUI
import Intents
import SpacePODShared
import Combine

class Provider: IntentTimelineProvider {
  func placeholder(in context: Context) -> APODTimelineEntry {
    return APODTimelineEntry(entry: .placeholder, configuration: ConfigurationIntent())
  }

  var cancellable: AnyCancellable?

  func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (APODTimelineEntry) -> ()) {

    cancellable = APODClient.shared.loadLatestImage().sink { completion in
      DBG("Latest image completion: \(completion)")
    } receiveValue: { cacheEntry in
      DBG("Latest image value \(cacheEntry)")
      completion(APODTimelineEntry(entry: cacheEntry, configuration: configuration))
    }
  }

  func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    getSnapshot(for: configuration, in: context) {
      completion(Timeline(entries: [$0], policy: .atEnd))
    }
  }
}

@main
struct APODWidget: Widget {
  let kind: String = "Widget"

  var body: some WidgetConfiguration {
    let config = IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) {
      APODEntryView(timelineEntry: $0)
        .widgetURL(Constants.widgetURL)
    }
    .configurationDisplayName("Space Photo of the Day")
    .description("See the latest image from NASA’s Astronomy Picture of the Day.")

    if #available(iOS 17.0, *) {
      // Allow image background (which is not removable) to fill whole widget.
      // See also: WidgetContentPaddingModifier
      return config.contentMarginsDisabled()
    } else {
      return config
    }
  }
}

@available(iOS 17.0, *)
#Preview("Widget preview", as: .systemSmall) {
  APODWidget()
} timeline: {
  let previewJSON = """
{
"copyright": "Adam Block",
"date": "2020-09-25",
"explanation": "The Great Spiral Galaxy in Andromeda (also known as M31), a mere 2.5 million light-years distant, is the closest large spiral to our own Milky Way. Andromeda is visible to the unaided eye as a small, faint, fuzzy patch, but because its surface brightness is so low, casual skygazers can't appreciate the galaxy's impressive extent in planet Earth's sky. This entertaining composite image compares the angular size of the nearby galaxy to a brighter, more familiar celestial sight. In it, a deep exposure of Andromeda, tracing beautiful blue star clusters in spiral arms far beyond the bright yellow core, is combined with a typical view of a nearly full Moon. Shown at the same angular scale, the Moon covers about 1/2 degree on the sky, while the galaxy is clearly several times that size. The deep Andromeda exposure also includes two bright satellite galaxies, M32 and M110 (below and right).",
"hdurl": "https://apod.nasa.gov/apod/image/2009/m31abtpmoon.jpg",
"media_type": "image",
"service_version": "v1",
"title": "Moon over Andromeda",
"url": "https://apod.nasa.gov/apod/image/2009/m31abtpmoon1024.jpg"
}
""".data(using: .utf8)!
  let videoPreviewJSON = """
{
"copyright": "Adam Block\\net al",
"date": "2020-09-25",
"explanation": "...",
"media_type": "video",
"service_version": "v1",
"title": "Moon over Andromeda",
"url": "https://www.youtube.com/embed/fbEcHDfi-vM?rel=0"
}
""".data(using: .utf8)!

  let photoEntry = configure(try! JSONDecoder().decode(APODEntry.self, from: previewJSON)) {
    $0.PREVIEW_overrideImage = #imageLiteral(resourceName: "sampleImage")
  }
  let photoEntryWide = configure(try! JSONDecoder().decode(APODEntry.self, from: previewJSON)) {
    let size = CGSize(width: 200, height: 50)
    $0.PREVIEW_overrideImage = UIGraphicsImageRenderer(size: size).image { _ in
      #imageLiteral(resourceName: "sampleImage").draw(in: CGRect(origin: .zero, size: size))
    }
  }
  let photoEntryTall = configure(try! JSONDecoder().decode(APODEntry.self, from: previewJSON)) {
    let size = CGSize(width: 50, height: 200)
    $0.PREVIEW_overrideImage = UIGraphicsImageRenderer(size: size).image { _ in
      #imageLiteral(resourceName: "sampleImage").draw(in: CGRect(origin: .zero, size: size))
    }
  }
  let videoEntry = configure(try! JSONDecoder().decode(APODEntry.self, from: videoPreviewJSON)) {
    $0.PREVIEW_overrideImage = #imageLiteral(resourceName: "sampleImage")
  }

  APODTimelineEntry(entry: photoEntry, configuration: ConfigurationIntent())
  APODTimelineEntry(entry: photoEntryWide, configuration: ConfigurationIntent())
  APODTimelineEntry(entry: photoEntryTall, configuration: ConfigurationIntent())
  APODTimelineEntry(entry: videoEntry, configuration: ConfigurationIntent())
}
