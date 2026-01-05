import Foundation
import mdict

/// Thin Swift wrapper for the C mdict API.
/// Usage:
/// ```swift
/// guard let dict = Mdict(path: "<path>/dict.mdx") else { return }
/// let meaning = dict.lookup(word: "hello")
/// let firstKeys = dict.getKeys(limit: 10)
/// ```
public class Mdict {
  private var dictHandle: UnsafeMutableRawPointer?

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

    return definition
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
