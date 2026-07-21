import Foundation
import mdict_cpp

/// A dictionary or resource archive backed by an MDict file.
///
/// Create one instance for each `.mdx` dictionary or `.mdd` resource archive.
///
/// Example:
/// ```swift
/// guard let dict = MDict(path: "/path/to/dictionary.mdx") else {
///   fatalError("Unable to open dictionary")
/// }
/// let meaning = dict.lookup(word: "hello")
/// let firstKeys = dict.getKeys(limit: 10)
/// ```
public class MDict {
  private var dictHandle: UnsafeMutableRawPointer?

  private static func normalizeBase64(_ value: String) -> String {
    let remainder = value.count % 4
    guard remainder != 0 else { return value }
    return value + String(repeating: "=", count: 4 - remainder)
  }

  private static func decodeHexString(_ value: String) -> Data? {
    guard value.isEmpty == false else { return nil }

    var bytes = Data()
    bytes.reserveCapacity(value.count / 2)

    var index = value.startIndex
    while index < value.endIndex {
      let nextIndex = value.index(index, offsetBy: 2, limitedBy: value.endIndex)
      guard let nextIndex else { return nil }
      let byteString = value[index..<nextIndex]
      guard let byte = UInt8(byteString, radix: 16) else { return nil }
      bytes.append(byte)
      index = nextIndex
    }

    return bytes
  }

  /// Opens an MDict dictionary or resource archive.
  ///
  /// Example:
  /// ```swift
  /// guard let dictionary = MDict(path: "/path/to/dictionary.mdx") else {
  ///   fatalError("Unable to open dictionary")
  /// }
  /// ```
  ///
  /// - Parameter path: The file-system path to an `.mdx` or `.mdd` file.
  /// - Returns: `nil` when the file does not exist or cannot be opened as an MDict file.
  public init?(path: String) {
    // iOS paths need to be handled carefully (sandbox)
    guard FileManager.default.fileExists(atPath: path) else {
      print("File does not exist at path: \(path)")
      return nil
    }

    path.withCString { cPath in
      self.dictHandle = mdict_init(cPath)
    }

    if self.dictHandle == nil {
      return nil
    }
  }

  deinit {
    if let handle = dictHandle {
      mdict_destory(handle)
    }
  }

  /// Looks up a word in an open `.mdx` dictionary.
  ///
  /// Example:
  /// ```swift
  /// guard let dictionary = MDict(path: "/path/to/dictionary.mdx") else {
  ///   fatalError("Unable to open dictionary")
  /// }
  /// if let definition = dictionary.lookup(word: "hello") {
  ///   print(definition)
  /// }
  /// ```
  ///
  /// - Parameter word: The dictionary key to look up.
  /// - Returns: The stored definition, commonly HTML, or `nil` when no nonempty entry exists.
  public func lookup(word: String) -> String? {
    guard let handle = dictHandle else { return nil }

    var result: UnsafeMutablePointer<CChar>?

    word.withCString { cWord in
      mdict_lookup(handle, cWord, &result)
    }

    guard let cString = result else { return nil }

    let definition = String(cString: cString)
    free(cString)  // mdict_lookup allocates memory using malloc/calloc

    let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedDefinition.isEmpty == false else { return nil }

    return definition
  }

  /// Loads a resource from an open `.mdd` archive.
  ///
  /// Example:
  /// ```swift
  /// let resources = MDict(path: "/path/to/dictionary.mdd")
  /// let imageData = resources?.locate(resource: "\\images\\logo.png")
  /// ```
  ///
  /// - Parameter resource: The resource key exactly as it is stored in the archive.
  /// - Returns: The decoded resource bytes, or `nil` when the resource cannot be found or decoded.
  public func locate(resource: String) -> Data? {
    guard let handle = dictHandle else { return nil }

    func locateRaw(_ encoding: mdict_encoding_t) -> String? {
      var result: UnsafeMutablePointer<CChar>?

      resource.withCString { cResource in
        mdict_locate(handle, cResource, &result, encoding)
      }

      guard let cString = result else { return nil }
      defer { free(cString) }  // mdict_locate allocates memory using malloc/calloc

      let value = String(cString: cString)
      return value.isEmpty ? nil : value
    }

    if let base64Value = locateRaw(MDICT_ENCODING_BASE64) {
      let normalizedBase64 = Self.normalizeBase64(base64Value)
      if let decoded = Data(base64Encoded: normalizedBase64, options: [.ignoreUnknownCharacters]) {
        return decoded
      }
    }

    if let hexValue = locateRaw(MDICT_ENCODING_HEX) {
      return Self.decodeHexString(hexValue)
    }

    return nil
  }

  /// Infers a MIME type from a resource filename.
  ///
  /// Example:
  /// ```swift
  /// let contentType = MDict.mimeType(for: "styles/main.css")
  /// // "text/css"
  /// ```
  ///
  /// - Parameter filename: A filename or resource path whose extension identifies its media type.
  /// - Returns: The detected MIME type, or `"application/octet-stream"` when it is unknown.
  public static func mimeType(for filename: String) -> String {
    return filename.withCString { cFilename in
      guard let cMime = c_mime_detect(cFilename) else {
        return "application/octet-stream"
      }
      return String(cString: cMime)
    }
  }

  /// Returns keys from the open dictionary or resource archive.
  ///
  /// Example:
  /// ```swift
  /// guard let dictionary = MDict(path: "/path/to/dictionary.mdx") else {
  ///   fatalError("Unable to open dictionary")
  /// }
  /// let firstTwentyKeys = dictionary.getKeys(limit: 20)
  /// ```
  ///
  /// - Parameter limit: The maximum number of keys to return. The default is `100`.
  /// - Returns: Up to `limit` keys, or an empty array when no keys are available.
  public func getKeys(limit: Int = 100) -> [String] {
    guard let handle = dictHandle else { return [] }

    var count: UInt64 = 0
    guard let keysPtr = mdict_keylist(handle, &count) else { return [] }

    var keys: [String] = []
    let numToRead = min(Int(count), limit)

    for i in 0..<numToRead {
      if let item = keysPtr[i], let keyWord = item.pointee.key_word {
        keys.append(String(cString: keyWord))
      }
    }

    free_simple_key_list(keysPtr, count)

    return keys
  }
}
