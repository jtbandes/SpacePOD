import Foundation
import libxml2

let newlinePattern = try! NSRegularExpression(pattern: #"\s*[\n\r]\s*"#)
let nonNewlinePattern = try! NSRegularExpression(pattern: #"[\t\f\p{Z}]+"#)

func stripHTML(_ raw: String) -> String? {
  guard let doc = XMLDoc(html: raw) else {
    return nil
  }

  let brElements = doc.elements(matchingXPath: "//br")
  for br in brElements {
    if let text = xmlNewDocText(doc.rawValue, "\n") {
      if let old = xmlReplaceNode(br, text) {
        xmlFreeNode(old)
      } else {
        xmlFreeNode(text)
      }
    }
  }

  guard var result = doc.textContent() else {
    return nil
  }
  result = newlinePattern.stringByReplacingMatches(
    in: result,
    range: NSRange(result.startIndex..<result.endIndex, in: result),
    withTemplate: "\n")
  result = nonNewlinePattern.stringByReplacingMatches(
    in: result,
    range: NSRange(result.startIndex..<result.endIndex, in: result),
    withTemplate: " ")
  return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Falls back to returning the original string if HTML parsing failed.
public func lenientStripHTML(_ raw: String) -> String {
  // Add a wrapper tag to try and make HTML fragments parseable.
  return stripHTML(raw) ?? raw
}

/// Attempt to extract a video or embed URL from `<video>` or `<iframe>` elements.
public func extractVideoURL(_ raw: String, relativeTo base: URL? = nil) -> URL? {
  guard let doc = XMLDoc(html: raw) else {
    return nil
  }

  let videos = doc.elements(matchingXPath: "//video/source")
  let iframes = doc.elements(matchingXPath: "//iframe")

  for element in videos + iframes {
    guard let src = xmlGetProp(element, "src") else {
      continue
    }
    defer {
      xmlFree(src)
    }
    if let url = URL(string: String(cString: src), relativeTo: base),
        url.scheme == "http" || url.scheme == "https" {
      return url.absoluteURL
    }
  }

  return nil
}

private struct XMLDoc: ~Copyable {
  let rawValue: xmlDocPtr

  init?(html: String) {
    let ptr = html.withCString {
      htmlReadDoc(
        $0, nil, "UTF-8", Int32(
          bitPattern:
            HTML_PARSE_RECOVER.rawValue
          | HTML_PARSE_NOERROR.rawValue
          | HTML_PARSE_NOWARNING.rawValue
          | HTML_PARSE_NONET.rawValue
          | HTML_PARSE_NOBLANKS.rawValue
        )
      )
    }
    guard let ptr else {
      return nil
    }
    self.rawValue = ptr
  }

  deinit {
    xmlFreeDoc(rawValue)
  }

  func textContent() -> String? {
    guard let rootEl = xmlDocGetRootElement(rawValue) else {
      return nil
    }
    guard let content = xmlNodeGetContent(rootEl) else {
      return nil
    }
    defer {
      xmlFree(content)
    }
    return String(cString: content)
  }

  func elements(matchingXPath query: String) -> [xmlNodePtr] {
    guard let xpathCtx = xmlXPathNewContext(rawValue) else {
      return []
    }
    defer {
      xmlXPathFreeContext(xpathCtx)
    }
    let xpathObj = query.withCString {
      xmlXPathEval($0, xpathCtx)
    }
    guard let xpathObj else {
      return []
    }
    defer {
      xmlXPathFreeObject(xpathObj)
    }
    guard let nodeSet = xpathObj.pointee.nodesetval,
          let nodeTab = nodeSet.pointee.nodeTab else {
      return []
    }
    let nodes = UnsafeBufferPointer(
      start: nodeTab,
      count: Int(nodeSet.pointee.nodeNr),
    )
    return nodes.compactMap { node in
      if let node, node.pointee.type == XML_ELEMENT_NODE {
        return node
      }
      return nil
    }
  }
}
