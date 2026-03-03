import ArgumentParser
import Foundation
import MDict

private struct MDictCLI: ParsableCommand {
  @Option(name: .long, help: "Path to .mdx file")
  var path: String?

  static let configuration = CommandConfiguration(
    commandName: "mdict-cli",
    abstract: "Command-line dictionary lookup for MDict files.",
    subcommands: [Lookup.self, Keys.self]
  )
}

private struct Lookup: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lookup",
    abstract: "Lookup a word in an .mdx dictionary."
  )

  @OptionGroup
  var global: MDictCLI

  @Argument(help: "Word to lookup")
  var word: String

  func run() throws {
    guard let path = global.path else {
      throw ValidationError("Missing required option: --path <mdx-file>")
    }

    guard let dict = Mdict(path: path) else {
      throw ValidationError("Failed to open dictionary at path: \(path)")
    }

    guard let definition = dict.lookup(word: word), definition.isEmpty == false else {
      fputs("Word not found: \(word)\n", stderr)
      throw ExitCode(3)
    }

    print(definition)
  }
}

private struct Keys: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "keys",
    abstract: "Print dictionary keys."
  )

  @OptionGroup
  var global: MDictCLI

  @Argument(help: "Max keys to print")
  var limit: Int = 100

  func run() throws {
    guard limit > 0 else {
      throw ValidationError("limit must be greater than 0")
    }

    guard let path = global.path else {
      throw ValidationError("Missing required option: --path <mdx-file>")
    }

    guard let dict = Mdict(path: path) else {
      throw ValidationError("Failed to open dictionary at path: \(path)")
    }

    let keys = dict.getKeys(limit: limit)
    for key in keys {
      print(key)
    }
  }
}

MDictCLI.main()
