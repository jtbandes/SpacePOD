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
    IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) {
      APODEntryView(timelineEntry: $0)
        .widgetURL(Constants.widgetURL)
    }
    .configurationDisplayName("Space Photo of the Day")
    .description("See the latest image from NASA’s Astronomy Picture of the Day.")
  }
}
