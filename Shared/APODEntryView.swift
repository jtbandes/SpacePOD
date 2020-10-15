import SwiftUI
import struct WidgetKit.WidgetPreviewContext

struct PhotoView: View {
  let configuration: ConfigurationIntent
  let date: Date?
  let image: AnyView?
  let caption: String?
  let copyright: String?

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)
        .ifLet(image) {
          $0.overlay($1)
        }

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          if configuration.showDate?.boolValue ?? true, let date = date {
            HStack {
              Spacer()
              Text(date, formatter: DateFormatter.monthDay)
                .font(.caption2)
            }
          }
          Spacer()
          if configuration.showTitle?.boolValue ?? true {
            if let caption = caption {
              Text(caption).font(.system(.footnote))
                .bold()
                .lineSpacing(-4)
            }
            if let copyright = copyright {
              Text(copyright).font(.system(.caption2))
            }
          }
        }
        Spacer()
      }
      .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 10))
      .foregroundColor(Color(.sRGB, white: 0.9))
      .shadow(color: .black, radius: 2, x: 0.0, y: 0.0)
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

  public var body: some View {
    let image = entry.loadImage(decode: false).map {
      let image = Image(uiImage: $0).resizable().aspectRatio(contentMode: .fill)
      if case .youtubeVideo = entry.asset {
        // FIXME: it might be nicer to switch at the top level, removing loadImage(), so we can't forget to handle videos separately elsewhere
        return image
          .overlay(
            ZStack {
              Color.gray
              image.opacity(0.8)
            }
            .blur(radius: 4)
            .brightness(0.2)
            .mask(Image(systemName: "play.circle.fill").font(.system(size: 40)).compositingGroup())
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

struct APODEntryView_Previews: PreviewProvider {
  static var previews: some View {
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
  "copyright": "Adam Block",
  "date": "2020-09-25",
  "explanation": "...",
  "media_type": "video",
  "service_version": "v1",
  "title": "Moon over Andromeda",
  "url": "https://www.youtube.com/embed/fbEcHDfi-vM?rel=0"
}
""".data(using: .utf8)!

    APODEntryView(
      entry: with(try! JSONDecoder().decode(APODEntry.self, from: videoPreviewJSON)) {
        $0.PREVIEW_overrideImage = #imageLiteral(resourceName: "sampleImage")
      })
      .previewContext(WidgetPreviewContext(family: .systemSmall))

    APODEntryView(
      entry: with(try! JSONDecoder().decode(APODEntry.self, from: previewJSON)) {
        $0.PREVIEW_overrideImage = #imageLiteral(resourceName: "sampleImage")
      })
      .previewContext(WidgetPreviewContext(family: .systemMedium))

    PhotoView(configuration: ConfigurationIntent(), date: Date(), image: AnyView(Image(uiImage: #imageLiteral(resourceName: "sampleImage")).resizable().aspectRatio(3, contentMode: .fill)), caption: "Hello", copyright: "There")
      .previewContext(WidgetPreviewContext(family: .systemMedium))

    PhotoView(configuration: ConfigurationIntent(), date: Date(), image: AnyView(Image(uiImage: #imageLiteral(resourceName: "sampleImage")).resizable().aspectRatio(0.3, contentMode: .fill)), caption: "Hello", copyright: "There")
      .previewContext(WidgetPreviewContext(family: .systemMedium))

    APODEntryView(
      entry: try! JSONDecoder().decode(APODEntry.self, from: previewJSON))
      .previewContext(WidgetPreviewContext(family: .systemMedium))
  }
}
