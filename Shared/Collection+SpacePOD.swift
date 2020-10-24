/// The result of a `binarySearch(_:)` operation.
public enum BinarySearchResult<T> {
  /// The target element was found at `index`.
  case present(index: T)
  /// The target element was not present in the collection; to maintain sorted order, it should be inserted at `insertionIndex`.
  case absent(insertionIndex: T)
}

public extension RangeReplaceableCollection where Element: Comparable {

  /// Perform a binary search for an element equal to `element`, returning the element's index if it is found, or the index where it should be inserted. If multiple elements equal to `element` are found, which index is returned is unspecified.
  /// - Precondition: The collection must be sorted.
  func binarySearch(_ element: Element) -> BinarySearchResult<Index> {
    var low = startIndex
    var high = endIndex
    while low < high {
      let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
      if element == self[mid] {
        return .present(index: mid)
      } else if element < self[mid] {
        high = mid
      } else {
        low = index(after: mid)
      }
    }
    return .absent(insertionIndex: low)
  }

}
