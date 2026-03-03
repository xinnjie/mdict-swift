import Foundation
import Testing

@testable import MDict

enum FixtureError: Error {
  case missing(String)
}

@Suite
struct MdictSwiftTests {
  private var mdict: Mdict?

  init() throws {
    guard
      let dictURL = Bundle.module.url(
        forResource: "testdict",
        withExtension: "mdx"
      )
    else {
      throw FixtureError.missing("Could not find testdict.mdx")
    }
    mdict = Mdict(path: dictURL.path)
    #expect(mdict != nil, "Failed to initialize Mdict")
  }

  private func makeEtymologyMDX() throws -> Mdict {
    guard
      let dictURL = Bundle.module.url(
        forResource: "etymonline",
        withExtension: "mdx",
        subdirectory: "fixtures/etymology"
      )
    else {
      throw FixtureError.missing("Could not find fixtures/etymology/etymonline.mdx")
    }
    guard let dict = Mdict(path: dictURL.path) else {
      throw FixtureError.missing("Failed to initialize etymonline.mdx")
    }
    return dict
  }

  private func makeEtymologyMDD() throws -> Mdict {
    guard
      let dictURL = Bundle.module.url(
        forResource: "etymonline",
        withExtension: "mdd",
        subdirectory: "fixtures/etymology"
      )
    else {
      throw FixtureError.missing("Could not find fixtures/etymology/etymonline.mdd")
    }
    guard let dict = Mdict(path: dictURL.path) else {
      throw FixtureError.missing("Failed to initialize etymonline.mdd")
    }
    return dict
  }

  @Test
  func lookupZoom() {
    let result = mdict?.lookup(word: "zoom")
    let expected =
      "<font size=+1 ><b>zoom</b></font> <br><br><font color=red ><b>verb</b></font><br> <span style=\"COLOR: blue;\"><i>a motorbike zoomed across their path</i></span> <syn><br><font COLOR= darkblue><b>SPEED </b></font>, streak, dash, rush, pelt, race, tear, shoot, blast, flash, fly, wing, scurry, scud, hurry, hasten, scramble, charge, chase, career, go like lightning, go hell for leather; <rl><font color=\"brown\">informal</font></rl> whizz, whoosh, vroom, buzz, hare, zip, whip, belt, scoot, scorch, burn rubber, go like a bat out of hell; <rl><font color=\"brown\">Brit. informal</font></rl> bomb, bucket, shift, put one's foot down, go like the clappers; <rl><font color=\"brown\">Scottish informal</font></rl> wheech; <rl><font color=\"brown\">N. Amer. informal</font></rl> boogie, hightail, clip, barrel, lay rubber, get the lead out; <rl><font color=\"brown\">N. Amer. vulgar slang</font></rl> drag/tear/haul ass; <rl><font color=\"brown\">informal, dated</font></rl> cut along; <rl><font color=\"brown\">archaic</font></rl> post, hie, fleet.</syn>\r\n"

    #expect(result == expected)
  }

  @Test
  func getKeys() {
    let keys = mdict?.getKeys(limit: 10)
    #expect(keys != nil, "Keys should not be nil")
    #expect(!(keys?.isEmpty ?? true), "Keys should not be empty")
    #expect(keys?.count == 10, "Should return requested number of keys")

    if let keys = keys {
      #expect(!keys[0].isEmpty, "Key should not be empty string")
    }
  }

  @Test
  func mimeTypeReturnsExpectedValues() {
    #expect(Mdict.mimeType(for: "style.css") == "text/css")
    #expect(Mdict.mimeType(for: "ICON.PNG") == "image/png")
    #expect(Mdict.mimeType(for: "audio.mp3") == "audio/mpeg")
    #expect(Mdict.mimeType(for: "unknown.extension") == "application/octet-stream")
  }

  @Test
  func locateMissingResourceReturnsNil() {
    let result = mdict?.locate(resource: "\\not-found-resource")
    #expect(result == nil)
  }

  @Test
  func lookupWorksWithEtymologyMDXFixture() throws {
    let etymologyMDX = try makeEtymologyMDX()
    let result = etymologyMDX.lookup(word: "hello")
    #expect(result?.isEmpty == false)
  }

  @Test
  func mddFixtureSupportsKeyListing() throws {
    let etymologyMDD = try makeEtymologyMDD()
    let keys = etymologyMDD.getKeys(limit: 5)
    #expect(keys.count == 5)
    #expect(keys.isEmpty == false)
  }

  @Test
  func locateSupportsMddFixtureResources() throws {
    let etymologyMDD = try makeEtymologyMDD()
    let keys = etymologyMDD.getKeys(limit: 1)
    #expect(keys.count == 1)

    guard let firstKey = keys.first else {
      Issue.record("Expected at least one key in etymology MDD fixture")
      return
    }

    let data = etymologyMDD.locate(resource: firstKey)
    #expect(data?.isEmpty == false)
  }
}
