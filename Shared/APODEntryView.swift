//
//  APODEntryView.swift
//  APODShared
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import SwiftUI
import struct WidgetKit.WidgetPreviewContext

public struct APODEntryView: View {
  let entry: APODEntry

  public init(entry: APODEntry) {
    self.entry = entry
  }

  public var body: some View {
    if let image = entry.loadImage() {
      ZStack(alignment: .leading) {
        Color.black.edgesIgnoringSafeArea(.all)

        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)

        VStack(alignment: .leading) {
//          Text(entry.date.asDate()!, style: .date).font(.caption2)
          Spacer()
          if let title = entry.title {
            Text(title).font(.system(.footnote)).bold()
          }
          if let copyright = entry.copyright {
            Text(copyright).font(.system(.caption2))
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundColor(Color(.sRGB, white: 0.9))
        .shadow(color: .black, radius: 2, x: 0.0, y: 0.0)
      }
    } else {
      ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 64, weight: .ultraLight))
          Text("Couldn‘t load image")
            .font(.footnote)
        }.foregroundColor(.gray)
      }
    }
  }
}

struct APODEntryView_Previews: PreviewProvider {
  static var previews: some View {
    let previewJSON = """
  {
  "copyright": "Luca Vanzella",
  "date": "2020-09-22",
  "explanation": "Does the Sun set in the same direction every day? No, the direction of sunset depends on the time of the year. Although the Sun always sets approximately toward the west, on an equinox like today the Sun sets directly toward the west. After today's September equinox, the Sun will set increasingly toward the southwest, reaching its maximum displacement at the December solstice.  Before today's September equinox, the Sun had set toward the northwest, reaching its maximum displacement at the June solstice. The featured time-lapse image shows seven bands of the Sun setting one day each month from 2019 December through 2020 June.  These image sequences were taken from Alberta, Canada -- well north of the Earth's equator -- and feature the city of Edmonton in the foreground.  The middle band shows the Sun setting during the last equinox -- in March.  From this location, the Sun will set along this same equinox band again today.",
  "hdurl": "https://apod.nasa.gov/apod/image/2009/SunsetMonths_Vanzella_2400.jpg",
  "media_type": "image",
  "service_version": "v1",
  "title": "Equinox in the Sky",
  "url": "https://apod.nasa.gov/apod/image/2009/SunsetMonths_Vanzella_1080_annotated.jpg"
  }
  """.data(using: .utf8)!

    APODEntryView(
      entry: with(try! JSONDecoder().decode(APODEntry.self, from: previewJSON)) {
        $0.PREVIEW_overrideImage = #imageLiteral(resourceName: "sampleImage")
      })
      .previewContext(WidgetPreviewContext(family: .systemSmall))

    APODEntryView(
      entry: try! JSONDecoder().decode(APODEntry.self, from: previewJSON))
      .previewContext(WidgetPreviewContext(family: .systemSmall))

    APODEntryView(
      entry: try! JSONDecoder().decode(APODEntry.self, from: previewJSON))
      .redacted(reason: .placeholder)
      .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
