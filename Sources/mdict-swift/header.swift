import Foundation
import mdict_cpp

extension MDict {
  public enum FileKind: Sendable, Equatable {
    case mdx
    case mdd
  }

  public enum TextEncoding: Sendable, Equatable {
    case utf8
    case utf16LittleEndian
    case utf16BigEndian
    case gb18030
    case big5
    case other(rawValue: String)
  }

  public enum ContentFormat: Sendable, Equatable {
    case html
    case text
    case other(rawValue: String)
  }

  public enum Encryption: Sendable, Equatable {
    case none
    case flags(UInt8)
    case other(rawValue: String)
  }

  public struct Header: Sendable, Equatable {
    public let fileKind: FileKind
    public let encoding: TextEncoding
    public let title: String?
    public let description: String?
    public let generatedByEngineVersion: String?
    public let requiredEngineVersion: String?
    public let contentFormat: ContentFormat?
    public let creationDate: String?
    public let encryption: Encryption
    public let isKeyCaseSensitive: Bool?
    public let stripsKeys: Bool?
    public let rawAttributes: [String: String]
  }

  /// Reads metadata without loading the dictionary's key or record indexes.
  public static func readHeader(atPath path: String) -> Header? {
    let handle = path.withCString { mdict_header_open($0) }
    guard let handle else { return nil }
    defer { mdict_header_close(handle) }

    guard let rootPointer = mdict_header_root_element(handle) else { return nil }
    let rootElement = String(cString: rootPointer)
    let fileKind: FileKind
    switch rootElement {
    case "Dictionary":
      fileKind = .mdx
    case "Library_Data":
      fileKind = .mdd
    default:
      return nil
    }

    var attributes: [String: String] = [:]
    for index in 0..<mdict_header_attribute_count(handle) {
      var keyPointer: UnsafePointer<CChar>?
      var valuePointer: UnsafePointer<CChar>?
      guard mdict_header_attribute_at(handle, index, &keyPointer, &valuePointer) == 0,
        let keyPointer, let valuePointer
      else {
        return nil
      }
      attributes[String(cString: keyPointer)] = String(cString: valuePointer)
    }

    return Header(fileKind: fileKind, attributes: attributes)
  }
}

extension MDict.Header {
  fileprivate init(fileKind: MDict.FileKind, attributes: [String: String]) {
    self.fileKind = fileKind
    self.rawAttributes = attributes

    // MDX has no authoritative public schema. In 32 sampled real files, MDX
    // used Dictionary and MDD used Library_Data, but optional fields, encoding
    // labels, extension attributes, and even StripKey/Stripkey varied. Keep the
    // complete attribute map and layer typed conveniences over it.
    // Format and compatibility references:
    // https://github.com/zhansliu/writemdict/blob/f0240b30cabd2f0470d3ee1a0641fc7f8c38dcf5/fileformat.md#header-section
    // https://github.com/liuyug/mdict-utils/blob/64e15b99aca786dbf65e5a2274f85547f8029f2e/mdict_utils/writer.py#L234-L299
    // https://github.com/ilius/pyglossary/blob/586fa21f36fb59b254306d876dd3ab01b8d43542/pyglossary/plugin_lib/readmdict.py#L340-L406
    let declaredEncoding = Self.attribute("Encoding", in: attributes) ?? ""
    self.encoding = Self.encoding(from: declaredEncoding, fileKind: fileKind)
    self.title = Self.nonemptyDecoded(Self.attribute("Title", in: attributes))
    self.description = Self.nonemptyDecoded(Self.attribute("Description", in: attributes))
    self.generatedByEngineVersion = Self.nonempty(
      Self.attribute("GeneratedByEngineVersion", in: attributes))
    self.requiredEngineVersion = Self.nonempty(
      Self.attribute("RequiredEngineVersion", in: attributes))
    self.creationDate = Self.nonempty(Self.attribute("CreationDate", in: attributes))
    self.contentFormat = Self.contentFormat(
      from: Self.attribute("Format", in: attributes))
    self.encryption = Self.encryption(
      from: Self.attribute("Encrypted", in: attributes))
    self.isKeyCaseSensitive = Self.boolean(
      from: Self.attribute("KeyCaseSensitive", in: attributes))
    self.stripsKeys = Self.boolean(
      from: Self.attribute("StripKey", aliases: ["Stripkey"], in: attributes))
  }

  private static func attribute(
    _ canonicalName: String,
    aliases: [String] = [],
    in attributes: [String: String]
  ) -> String? {
    let acceptedNames = [canonicalName] + aliases
    for name in acceptedNames {
      if let value = attributes[name] {
        return value
      }
    }

    // Some generators change attribute capitalization. Only accept a
    // case-insensitive fallback when it identifies exactly one raw field.
    let foldedNames = Set(acceptedNames.map(Self.asciiLowercased))
    let matches = attributes.filter { foldedNames.contains(asciiLowercased($0.key)) }
    return matches.count == 1 ? matches.first?.value : nil
  }

  private static func asciiLowercased(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.utf8.count)
    for scalar in value.unicodeScalars {
      if (65...90).contains(scalar.value), let lowercase = Unicode.Scalar(scalar.value + 32) {
        result.unicodeScalars.append(lowercase)
      } else {
        result.unicodeScalars.append(scalar)
      }
    }
    return result
  }

  private static func encoding(
    from rawValue: String,
    fileKind: MDict.FileKind
  ) -> MDict.TextEncoding {
    // MDD keys are UTF-16LE even though real MDD headers generally declare
    // Encoding=""; both writemdict and mdict-utils document/emit this behavior.
    if fileKind == .mdd {
      return .utf16LittleEndian
    }

    let normalized = rawValue
      .filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
      .uppercased()
    switch normalized {
    case "UTF8": return .utf8
    case "UTF16", "UTF16LE": return .utf16LittleEndian
    case "UTF16BE": return .utf16BigEndian
    case "GBK", "GB2312", "GB18030": return .gb18030
    case "BIG5": return .big5
    default: return .other(rawValue: rawValue)
    }
  }

  private static func contentFormat(from rawValue: String?) -> MDict.ContentFormat? {
    guard let rawValue = nonempty(rawValue) else { return nil }
    switch rawValue.lowercased() {
    case "html": return .html
    case "text": return .text
    default: return .other(rawValue: rawValue)
    }
  }

  private static func encryption(from rawValue: String?) -> MDict.Encryption {
    guard let rawValue = nonempty(rawValue) else { return .none }
    switch rawValue.lowercased() {
    case "no", "0": return .none
    case "yes": return .flags(1)
    default:
      return UInt8(rawValue).map(MDict.Encryption.flags)
        ?? .other(rawValue: rawValue)
    }
  }

  private static func boolean(from rawValue: String?) -> Bool? {
    switch rawValue?.lowercased() {
    case "yes", "true", "1": return true
    case "no", "false", "0": return false
    default: return nil
    }
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return value
  }

  private static func nonemptyDecoded(_ value: String?) -> String? {
    guard let value = nonempty(value) else { return nil }
    return decodeXMLEntitiesOnce(value)
  }

  private static func decodeXMLEntitiesOnce(_ value: String) -> String {
    var result = ""
    var index = value.startIndex
    while index < value.endIndex {
      guard value[index] == "&",
        let semicolon = value[index...].firstIndex(of: ";")
      else {
        result.append(value[index])
        index = value.index(after: index)
        continue
      }

      let tokenStart = value.index(after: index)
      let token = String(value[tokenStart..<semicolon])
      if let replacement = decodedEntity(token) {
        result.append(replacement)
      } else {
        result.append(contentsOf: value[index...semicolon])
      }
      index = value.index(after: semicolon)
    }
    return result
  }

  private static func decodedEntity(_ token: String) -> String? {
    switch token {
    case "amp": return "&"
    case "lt": return "<"
    case "gt": return ">"
    case "quot": return "\""
    case "apos": return "'"
    default:
      let scalarValue: UInt32?
      if token.hasPrefix("#x") || token.hasPrefix("#X") {
        scalarValue = UInt32(token.dropFirst(2), radix: 16)
      } else if token.hasPrefix("#") {
        scalarValue = UInt32(token.dropFirst())
      } else {
        scalarValue = nil
      }
      guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { return nil }
      return String(scalar)
    }
  }
}
