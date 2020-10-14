import Foundation

public struct SortedDictionary<Key: Hashable & Comparable, Value>: BidirectionalCollection {
  var _dict: [Key: Value] = [:]
  var _keys: [Key] = []

  public init() {}

  public subscript(key: Key) -> Value? {
    get {
      return _dict[key]
    }

    set {
      _dict[key] = newValue

      switch _keys.binarySearch(key) {
      case .present(let index):
        if newValue != nil {
          _keys[index] = key
        } else {
          _keys.remove(at: index)
        }
      case .absent(let insertionIndex):
        if newValue != nil {
          _keys.insert(key, at: insertionIndex)
        }
      }
    }
  }

}

extension SortedDictionary: Collection {
  public var startIndex: Int { _keys.startIndex }
  public var endIndex: Int { _keys.endIndex }

  public func index(before i: Int) -> Int {
    return i - 1
  }
  public   func index(after i: Int) -> Int {
    return i + 1
  }
  public subscript(position: Int) -> (key: Key, value: Value) {
    let key = _keys[position]
    return (key, _dict[key]!)
  }
}

extension SortedDictionary: CustomDebugStringConvertible {
  public var debugDescription: String {
    "\(Self.self)(\(count)) {\n" + self.map { "\t- [\(reflecting: $0.key)]: \(reflecting: $0.value)" }.joined(separator: "\n") + "\n}"
  }
}
