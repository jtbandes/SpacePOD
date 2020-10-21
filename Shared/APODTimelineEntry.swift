import WidgetKit
import Intents

public struct APODTimelineEntry: TimelineEntry {
  public let entry: APODEntry
  public let configuration: ConfigurationIntent

  public init(entry: APODEntry, configuration: ConfigurationIntent) {
    self.entry = entry
    self.configuration = configuration
  }

  public var date: Date {
    entry.date.asDate() ?? Date()
  }

  public var relevance: TimelineEntryRelevance? {
    TimelineEntryRelevance(score: 1, duration: 24*60*60)
  }
}
