import Foundation
import Testing

@testable import MDict

enum FixtureError: Error {
  case missing(String)
}

private func writeHeaderOnlyFile(extension fileExtension: String, xml: String) throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension(fileExtension)
  let utf16 = Array(xml.utf16) + [0]
  var data = Data()
  let byteCount = UInt32(utf16.count * 2)
  data.append(contentsOf: [
    UInt8((byteCount >> 24) & 0xff), UInt8((byteCount >> 16) & 0xff),
    UInt8((byteCount >> 8) & 0xff), UInt8(byteCount & 0xff),
  ])
  for codeUnit in utf16 {
    data.append(UInt8(codeUnit & 0xff))
    data.append(UInt8(codeUnit >> 8))
  }
  data.append(contentsOf: [0, 0, 0, 0])
  try data.write(to: url)
  return url
}

@Suite
struct MDictSwiftTests {
  private var mdict: MDict?

  init() throws {
    guard
      let dictURL = Bundle.module.url(
        forResource: "testdict",
        withExtension: "mdx",
        subdirectory: "testdict"
      )
    else {
      throw FixtureError.missing("Could not find testdict/testdict.mdx")
    }
    mdict = MDict(path: dictURL.path)
    #expect(mdict != nil, "Failed to initialize MDict")
  }

  @Test("Looks up an existing dictionary entry")
  func lookupZoom() {
    let result = mdict?.lookup(word: "zoom")
    let expected =
      "<font size=+1 ><b>zoom</b></font> <br><br><font color=red ><b>verb</b></font><br> <span style=\"COLOR: blue;\"><i>a motorbike zoomed across their path</i></span> <syn><br><font COLOR= darkblue><b>SPEED </b></font>, streak, dash, rush, pelt, race, tear, shoot, blast, flash, fly, wing, scurry, scud, hurry, hasten, scramble, charge, chase, career, go like lightning, go hell for leather; <rl><font color=\"brown\">informal</font></rl> whizz, whoosh, vroom, buzz, hare, zip, whip, belt, scoot, scorch, burn rubber, go like a bat out of hell; <rl><font color=\"brown\">Brit. informal</font></rl> bomb, bucket, shift, put one's foot down, go like the clappers; <rl><font color=\"brown\">Scottish informal</font></rl> wheech; <rl><font color=\"brown\">N. Amer. informal</font></rl> boogie, hightail, clip, barrel, lay rubber, get the lead out; <rl><font color=\"brown\">N. Amer. vulgar slang</font></rl> drag/tear/haul ass; <rl><font color=\"brown\">informal, dated</font></rl> cut along; <rl><font color=\"brown\">archaic</font></rl> post, hie, fleet.</syn>\r\n"

    #expect(result == expected)
  }

  @Test("Exposes a metadata snapshot on an open dictionary")
  func instanceHeader() {
    #expect(mdict?.header.fileKind == .mdx)
    #expect(mdict?.header.encoding == .utf8)
    #expect(mdict?.header.rawAttributes["Encoding"] == "UTF-8")
  }

  @Test("Reads and normalizes a header without indexes")
  func readsHeaderOnlyMDD() throws {
    let url = try writeHeaderOnlyFile(
      extension: "mdd",
      xml: "<Library_Data Encoding=\"\" TITLE=\"A &amp; B\" Description=\"&amp;lt;b&amp;gt;Hi&amp;lt;/b&amp;gt; &eacute; &#x1F600;\" GeneratedByEngineVersion=\"2.0\" RequiredEngineVersion=\"2.0\" Format=\"\" CreationDate=\"\" Encrypted=\"2\" KeyCaseSensitive=\"No\" Stripkey=\"Yes\" Filters=\"x\"/>"
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let header = MDict.readHeader(atPath: url.path)
    #expect(header?.fileKind == .mdd)
    #expect(header?.encoding == .utf16LittleEndian)
    #expect(header?.title == "A & B")
    #expect(header?.description == "&lt;b&gt;Hi&lt;/b&gt; &eacute; 😀")
    #expect(header?.generatedByEngineVersion == "2.0")
    #expect(header?.requiredEngineVersion == "2.0")
    #expect(header?.contentFormat == nil)
    #expect(header?.creationDate == nil)
    #expect(header?.encryption == .flags(2))
    #expect(header?.isKeyCaseSensitive == false)
    #expect(header?.stripsKeys == true)
    #expect(header?.rawAttributes["Encoding"] == "")
    #expect(header?.rawAttributes["Filters"] == "x")
  }

  @Test("Normalizes MDX labels and preserves unknown values")
  func normalizesMDXMetadata() throws {
    let url = try writeHeaderOnlyFile(
      extension: "mdx",
      xml: "<Dictionary Encoding=\"GB2312\" Title=\"  \" Format=\"Markdown\" Encrypted=\"custom\" StripKey=\"maybe\"/>"
    )
    defer { try? FileManager.default.removeItem(at: url) }

    let header = MDict.readHeader(atPath: url.path)
    #expect(header?.encoding == .gb18030)
    #expect(header?.title == nil)
    #expect(header?.contentFormat == .other(rawValue: "Markdown"))
    #expect(header?.encryption == .other(rawValue: "custom"))
    #expect(header?.stripsKeys == nil)
    #expect(header?.rawAttributes["Title"] == "  ")
  }

  @Test(
    "Normalizes common encoding spellings",
    arguments: [
      ("UTF8", MDict.TextEncoding.utf8),
      ("utf-16", MDict.TextEncoding.utf16LittleEndian),
      ("UTF_16BE", MDict.TextEncoding.utf16BigEndian),
      ("GBK", MDict.TextEncoding.gb18030),
      ("Big5", MDict.TextEncoding.big5),
      ("ISO8859-1", MDict.TextEncoding.other(rawValue: "ISO8859-1")),
    ]
  )
  func normalizesEncoding(label: String, expected: MDict.TextEncoding) throws {
    let url = try writeHeaderOnlyFile(
      extension: "mdx",
      xml: "<Dictionary Encoding=\"\(label)\"/>"
    )
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(MDict.readHeader(atPath: url.path)?.encoding == expected)
  }

  @Test("Rejects missing and non-MDict headers")
  func invalidHeaders() throws {
    #expect(MDict.readHeader(atPath: "/path/that/does/not/exist.mdx") == nil)
    let url = try writeHeaderOnlyFile(extension: "mdx", xml: "<Unknown Encoding=\"UTF-8\"/>")
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(MDict.readHeader(atPath: url.path) == nil)
  }

  @Test("Returns the requested number of dictionary keys")
  func getKeys() {
    let keys = mdict?.getKeys(limit: 10)
    #expect(keys != nil, "Keys should not be nil")
    #expect(!(keys?.isEmpty ?? true), "Keys should not be empty")
    #expect(keys?.count == 10, "Should return requested number of keys")

    if let keys = keys {
      #expect(!keys[0].isEmpty, "Key should not be empty string")
    }
  }

  @Test("Detects known MIME types and falls back for unknown extensions")
  func mimeTypeReturnsExpectedValues() {
    #expect(MDict.mimeType(for: "style.css") == "text/css")
    #expect(MDict.mimeType(for: "ICON.PNG") == "image/png")
    #expect(MDict.mimeType(for: "audio.mp3") == "audio/mpeg")
    #expect(MDict.mimeType(for: "unknown.extension") == "application/octet-stream")
  }

  @Test("Returns nil when an MDD resource is missing")
  func locateMissingResourceReturnsNil() {
    let result = mdict?.locate(resource: "\\not-found-resource")
    #expect(result == nil)
  }

  @Test("Returns nil when a dictionary word is missing")
  func lookupMissingWordReturnsNil() {
    let result = mdict?.lookup(word: "word-that-does-not-exist-in-testdict")

    #expect(result == nil)
  }
}
