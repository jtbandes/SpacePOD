import WidgetKit
import SwiftUI
import Intents
import APODShared
import Combine

class Provider: IntentTimelineProvider {
  func placeholder(in context: Context) -> APODTimelineEntry {
    return APODTimelineEntry(entry: .placeholder, configuration: ConfigurationIntent())
  }

  var cancellable: AnyCancellable?

  func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (APODTimelineEntry) -> ()) {

    cancellable = APODClient.shared.loadLatestImage().sink { completion in
      print("Latest image completion: \(completion)")
    } receiveValue: { cacheEntry in
      print("Latest image value \(cacheEntry)")
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
    }
    .configurationDisplayName("Astronomy Photo of the Day")
    .description("See the latest photo from NASA.")
  }
}
