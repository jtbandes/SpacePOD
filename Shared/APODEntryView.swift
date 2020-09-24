//
//  APODEntryView.swift
//  APODShared
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import SwiftUI

public struct APODEntryView: View {
  let entry: APODCacheEntry

  public init(entry: APODCacheEntry) {
    self.entry = entry
  }

  public var body: some View {
    if let image = UIImage(contentsOfFile: entry.localImageURL.path) {
      Image(uiImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
    } else {
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 64, weight: .ultraLight))
        Text("Couldn‘t load image")
          .font(.footnote)
      }.foregroundColor(.secondary)
    }
  }
}
