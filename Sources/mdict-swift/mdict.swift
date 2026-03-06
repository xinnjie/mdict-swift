import Foundation
import mdict_cpp

/// Thin Swift wrapper for the C mdict API.
/// Usage:
/// ```swift
/// guard let dict = Mdict(path: "<path>/dict.mdx") else { return }
/// let meaning = dict.lookup(word: "hello")
/// let firstKeys = dict.getKeys(limit: 10)
/// ```
public class Mdict {
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

  public static func mimeType(for filename: String) -> String {
    return filename.withCString { cFilename in
      guard let cMime = c_mime_detect(cFilename) else {
        return "application/octet-stream"
      }
      return String(cString: cMime)
    }
  }

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
