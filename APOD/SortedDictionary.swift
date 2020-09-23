//
//  SortedDictionary.swift
//  APOD
//
//  Created by Jacob Bandes-Storch on 9/23/20.
//

import Foundation


struct SortedDictionary<Key: Hashable & Comparable, Value>: BidirectionalCollection {
  var _dict: [Key: Value] = [:]
  var _keys: [Key] = []

  subscript(key: Key) -> Value? {
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
  var startIndex: Int { _keys.startIndex }
  var endIndex: Int { _keys.endIndex }

  func index(before i: Int) -> Int {
    return i - 1
  }
  func index(after i: Int) -> Int {
    return i + 1
  }
  subscript(position: Int) -> (key: Key, value: Value) {
    let key = _keys[position]
    return (key, _dict[key]!)
  }
}
