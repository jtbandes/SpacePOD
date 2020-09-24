//
//  Widget.swift
//  Widget
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import WidgetKit
import SwiftUI
import Intents
import APODShared
import Combine

struct APODTimelineEntry: TimelineEntry {
  let cacheEntry: APODEntry?
  let configuration: ConfigurationIntent
  var date: Date {
    cacheEntry?.date.asDate() ?? Date()
  }
}

class Provider: IntentTimelineProvider {
  func placeholder(in context: Context) -> APODTimelineEntry {
    APODTimelineEntry(cacheEntry: nil, configuration: ConfigurationIntent())
  }

  var cancellable: AnyCancellable?

  func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (APODTimelineEntry) -> ()) {

    cancellable = APODClient.shared.loadLatestImage().sink { completion in
      print("Fail :( \(completion)")
    } receiveValue: { cacheEntry in
      completion(APODTimelineEntry(cacheEntry: cacheEntry, configuration: configuration))
    }
  }

  func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {

    getSnapshot(for: configuration, in: context) {
      completion(Timeline(entries: [$0], policy: .atEnd))
    }
  }
}

struct WidgetEntryView : View {
  var entry: APODTimelineEntry

  var body: some View {
    entry.cacheEntry.map {
      APODEntryView(entry: $0)
    }
  }
}

@main
struct APODWidget: Widget {
  let kind: String = "Widget"

  var body: some WidgetConfiguration {
    IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
      WidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Astronomy Photo of the Day")
    .description("See the latest photo from NASA.")
  }
}
