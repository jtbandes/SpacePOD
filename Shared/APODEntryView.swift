import SwiftUI
import struct WidgetKit.WidgetPreviewContext

extension Text {
  /// Unexpected truncation of Text labels with a .font() set was observed on macOS.
  ///  https://www.hackingwithswift.com/forums/swiftui/stop-text-being-truncated/1535
  func workAroundTextTruncationBug() -> some View {
    return self.minimumScaleFactor(0.9)
  }
}

@available(iOS 16.0, *)
struct IfFullColorRenderingModeImpl<Then: View, Else: View>: View {
  @Environment(\.widgetRenderingMode) var widgetRenderingMode
  var thenBody: Then
  var elseBody: Else

  var body: some View {
    if case .fullColor = widgetRenderingMode {
      thenBody
    } else {
      elseBody
    }
  }
}

struct IfFullColorRenderingMode<Then: View, Else: View>: View {
  @ViewBuilder var thenBody: Then
  @ViewBuilder var elseBody: Else

  var body: some View {
    if #available(iOS 16.0, *) {
      IfFullColorRenderingModeImpl<Then, Else>(thenBody: thenBody, elseBody: elseBody)
    } else {
      elseBody
    }
  }
}

extension View {
  func addRenderingModeSpecificShadow() -> some View {
    IfFullColorRenderingMode {
      self
        .shadow(color: .black, radius: 2, x: 0.0, y: 0.0)
    } elseBody: {
      self
    }
  }
}

struct PhotoView: View {
  let configuration: ConfigurationIntent
  let date: Date?
  let image: AnyView?
  let caption: String?
  let copyright: String?

  var body: some View {
    let content =
      VStack(alignment: .leading, spacing: 4) {
        if configuration.showDate?.boolValue ?? true, let date = date {
          HStack {
            Spacer()
            Text(date, formatter: DateFormatter.monthDay)
              .font(.caption2)
              .workAroundTextTruncationBug()
          }
        }
        Spacer()
        if configuration.showTitle?.boolValue ?? true {
          if let caption = caption {
            Text(caption).font(.system(.footnote))
              .bold()
              .workAroundTextTruncationBug()
              .lineSpacing(-4)
          }
          if let copyright = copyright {
            Text(copyright).font(.system(.caption2))
              .workAroundTextTruncationBug()
          }
        }
      }
      .addWidgetContentPadding(fallback: EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 10))
      .foregroundColor(Color(.sRGB, white: 0.9))
      .addRenderingModeSpecificShadow()
      .flexibleFrame()
      .background(image)

    if #available(iOS 17.0, *) {
      content.containerBackground(.clear, for: .widget)
    } else {
      content
    }
  }
}

public struct APODEntryView: View {
  let entry: APODEntry
  let configuration: ConfigurationIntent

  public init(timelineEntry: APODTimelineEntry) {
    self.entry = timelineEntry.entry
    self.configuration = timelineEntry.configuration
  }

  public init(entry: APODEntry) {
    self.entry = entry
    self.configuration = ConfigurationIntent()
  }

  public/*FIXME*/ static let failureImage = AnyView(
    Image(systemName: "exclamationmark.triangle")
      .font(.system(size: 64, weight: .ultraLight))
      .foregroundColor(Color(.sRGB, white: 0.5)))

  public static let missingImage = AnyView(
    Image(systemName: "moon.stars")
      .font(.system(size: 64, weight: .ultraLight))
      .foregroundColor(Color(.sRGB, white: 0.5)))

  public var body: some View {
    let image = entry.loadImage(enableAnimatedGIF: false).map {
      let image = Image(uiImage: $0)
        .resizable()
        .widgetDesaturated()
        .aspectRatio(contentMode: .fill)
      if entry.asset.isVideo {
        return image
          .overlay(
            IfFullColorRenderingMode {
              ZStack {
                Color.gray
                image.opacity(0.8)
              }
              .blur(radius: 4)
              .brightness(0.2)
              .mask(Image(systemName: "play.circle.fill").font(.system(size: 40)).compositingGroup())
            } elseBody: {
              Image(systemName: "play.fill").font(.system(size: 40)).opacity(0.3)
            }
          )
          .eraseToAnyView()
      }
      return image.eraseToAnyView()
    } ?? APODEntryView.failureImage

    PhotoView(
      configuration: configuration,
      date: entry.date.asDate()!,
      image: image,
      caption: entry.title,
      copyright: entry.copyright)
  }
}
