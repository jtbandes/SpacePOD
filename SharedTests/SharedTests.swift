import Foundation
import Testing
@testable import SpacePODShared

@Test func testStripHTML() {
  #expect(stripHTML("Hi") == "Hi")
  #expect(stripHTML(" <b> Hi </b> ") == "Hi")
  #expect(stripHTML("Hi</b>") == "Hi")
  #expect(stripHTML("<b>Hi") == "Hi")

  #expect(stripHTML("<z><a>hello,</a> <b>world</b></z>") == "hello, world")
  #expect(stripHTML(" <z> <a> hello, </a> <b> world </b> </z> ") == "hello, world")
  #expect(stripHTML(" \n <z> <a> hello, </a> \n <b> world </b> \n </z> ") == "hello,\nworld")

  #expect(stripHTML("<a>Petr Hor\u{00e1}lek</a>") == "Petr Hor\u{00e1}lek")

  #expect(stripHTML("<a>hello<br>world</a>") == "hello\nworld")
}

@Test func testExtractVideoURL() {
  #expect(extractVideoURL(#"Hi"#) == nil)
  #expect(extractVideoURL(#"<video>nothing</video>"#) == nil)
  #expect(extractVideoURL(#"<video><source>nothing</source></video>"#) == nil)
  #expect(extractVideoURL(#"<video><source src="hi">nothing</source></video>"#) == nil)
  #expect(extractVideoURL(#"<video><source src="http://example.com">nothing</source></video>"#) == URL(string: "http://example.com")!)

  #expect(extractVideoURL(#"<center><iframe width="960" height="540" src="//www.youtube.com/embed/DzrCEm1ZBRY?rel=0" frameborder="0" allowfullscreen></iframe></center>"#)
          == nil)

  #expect(extractVideoURL(#"<center><iframe width="960" height="540" src="//www.youtube.com/embed/DzrCEm1ZBRY?rel=0" frameborder="0" allowfullscreen></iframe></center>"#,
                          relativeTo: URL(string: "https://example.com/foo")!)
          == URL(string: "https://www.youtube.com/embed/DzrCEm1ZBRY?rel=0")!)
}

@Test func apodEntryCoding() throws {
  let json = #"""
    {
      "date": "2026-10-14",
      "post_id": 1487715,
      "title": "Mars and the Beehive Under an Aurora",
      "permalink": "https://science.nasa.gov/image-article/apod-2026-october-14-mars-and-the-beehive-under-an-aurora/",
      "media_type": "image",
      "explanation": "...",
      "alt": "...",
      "url": "https://science.nasa.gov/image-article/apod-2026-october-14-mars-and-the-beehive-under-an-aurora/",
      "hdurl": "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/2026_10_10_PZ_Jesli\u010dky_01_1500px.png?w=1500&h=1000&fit=clip&crop=faces%2Cfocalpoint",
      "basic_html": "...",
      "basic_html_url": "https://science.nasa.gov/wp-json/wp/v2/apod-basic/261014/html"
    }
    """#

  // Fails to decode if apiSource is absent from JSON and userInfo
  let decoder = JSONDecoder()
  #expect(throws: APODErrors.missingApiSource) {
    try decoder.decode(RawAPODEntry.self, from: json.data(using: .utf8)!)
  }

  // Decodes successfully when provided with userInfo
  decoder.userInfo[.defaultAPISource] = APODAPISource.wordpress
  let entry = try decoder.decode(RawAPODEntry.self, from: json.data(using: .utf8)!)
  #expect(entry.apiSource == .wordpress)
  #expect(entry.date == YearMonthDay(year: 2026, month: 10, day: 14))
  #expect(entry.hdurl ==  "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/2026_10_10_PZ_Jesli\u{010d}ky_01_1500px.png?w=1500&h=1000&fit=clip&crop=faces%2Cfocalpoint")
  #expect(entry.url == "https://science.nasa.gov/image-article/apod-2026-october-14-mars-and-the-beehive-under-an-aurora/")
  #expect(entry.explanation == "...")
  #expect(entry.mediaType == "image")

  // Encodes apiSource into JSON
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  let reEncodedJson = String(data: try encoder.encode(entry), encoding: .utf8)!
  #expect(reEncodedJson == #"""
    {
      "__spacepod_api_source" : "wordpress",
      "basic_html" : "...",
      "date" : "2026-10-14",
      "explanation" : "...",
      "hdurl" : "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/october/2026_10_10_PZ_Jesličky_01_1500px.png?w=1500&h=1000&fit=clip&crop=faces%2Cfocalpoint",
      "media_type" : "image",
      "title" : "Mars and the Beehive Under an Aurora",
      "url" : "https://science.nasa.gov/image-article/apod-2026-october-14-mars-and-the-beehive-under-an-aurora/"
    }
    """#)

  // Decodes JSON successfully without userInfo when apiSource is present
  let fullRoundTrip = try JSONDecoder().decode(RawAPODEntry.self, from: reEncodedJson.data(using: .utf8)!)
  #expect(entry == fullRoundTrip)
}
