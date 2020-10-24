public extension Optional {

  /// Unwrap the optional, throwing an error if it contained `nil`.
  func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
    if let self = self {
      return self
    }
    throw error()
  }

  /// Unwrap the optional, stopping program execution with a fatal error message if it contained `nil`.
  func orFatalError(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) -> Wrapped {
    if let self = self {
      return self
    }
    fatalError(message(), file: file, line: line)
  }

  /// Convert the optional to a `Result`, replacing `nil` values with the given error.
  ///
  /// ```
  /// let maybeInt: Int?
  /// let result = maybeInt.asResult(ifNil: MyError.missingInteger)
  /// ```
  func asResult<Failure>(ifNil makeError: @autoclosure () -> Failure) -> Result<Wrapped, Failure> {
    if let self = self {
      return .success(self)
    }
    return .failure(makeError())
  }

  /// Accesses the optional via a "view" that presents it as a non-optional value. If the underlying optional was `nil`, the given `defaultValue` will be used instead.
  ///
  /// This allows mutating methods to be used without optional chaining. For example:
  /// ```
  /// var maybeArray: [Int]?
  ///
  /// maybeArray?.append(42)  // bad: doesn't append if there was no array
  ///
  /// maybeArray[withDefault: []].append(42)  // good: always appends
  /// ```
  ///
  /// - Note: See discussion at <https://forums.swift.org/t/mutating-t-with-a-default-value-or-returning-inout-or-extending-any/40593>
  subscript(withDefault defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
    get {
      return self ?? defaultValue()
    }
    set {
      self = newValue
    }

    // Possibly more efficient "generalized accessors" as described in the Ownership Manifesto:
    // https://github.com/apple/swift/blob/main/docs/OwnershipManifesto.md#generalized-accessors
//    _read {
//      yield self ?? value()
//    }
//    _modify {
//      if self == nil { self = value() }
//      yield &self!
//    }
  }
}
