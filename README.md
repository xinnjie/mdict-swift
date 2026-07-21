# MDict Swift

A thin Swift wrapper around [MDict-cpp](https://github.com/dictlab/mdict-cpp) for reading MDict dictionaries and resources.

- Open `.mdx` files and look up dictionary entries.
- Open `.mdd` files and load images, stylesheets, audio, and other resources.
- Use the library from iOS or macOS, or inspect a dictionary with the included CLI.

## Mental model

```text
.mdx file -> Mdict -> lookup(word:)      -> String? (usually raw HTML)
                   -> getKeys(limit:)    -> [String]

.mdd file -> Mdict -> locate(resource:)  -> Data?
                   -> getKeys(limit:)    -> [String]

filename  -> Mdict.mimeType(for:)        -> MIME type
```

`Mdict` opens one file at a time. A dictionary that references external assets will typically use one `Mdict` instance for its `.mdx` content and another for the matching `.mdd` resources. The library returns the stored content; rendering dictionary HTML is the application's responsibility.

## Requirements

- Swift 6.0 or later
- iOS 13 or later
- macOS 10.15 or later

## Installation

Add the package dependency in Xcode, or declare it in `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/xinnjie/mdict-swift.git",
    from: "0.0.3"
  )
]
```

Then add the `mdict` product to your target:

```swift
.target(
  name: "YourTarget",
  dependencies: [
    .product(name: "mdict", package: "mdict-swift")
  ]
)
```

Import the module as `MDict`.

## Usage

### Look up an MDX entry

```swift
import MDict

guard let dictionary = Mdict(path: "/path/to/dictionary.mdx") else {
  fatalError("Unable to open dictionary")
}

if let definition = dictionary.lookup(word: "hello") {
  // Definitions are commonly HTML rather than plain text.
  print(definition)
}

let firstKeys = dictionary.getKeys(limit: 20)
```

### Load an MDD resource

```swift
guard let resources = Mdict(path: "/path/to/dictionary.mdd") else {
  fatalError("Unable to open resources")
}

let resourceName = "\\images\\logo.png"
if let data = resources.locate(resource: resourceName) {
  let contentType = Mdict.mimeType(for: resourceName)
  print("Loaded \(data.count) bytes as \(contentType)")
}
```

Resource names must match the keys stored in the MDD file. Use `getKeys(limit:)` to inspect them when needed.

## Public API

The Swift API intentionally consists of one type:

| API | Result |
| --- | --- |
| `Mdict(path:)` | Opens an MDX or MDD file. Returns `nil` when the file is missing or cannot be parsed. |
| `lookup(word:)` | Returns the stored entry, usually HTML, or `nil` when the word is not found. |
| `getKeys(limit:)` | Returns up to `limit` keys from the open file. The default limit is `100`. |
| `locate(resource:)` | Returns an MDD resource as `Data`, or `nil` when it cannot be found or decoded. |
| `Mdict.mimeType(for:)` | Infers a MIME type from a filename, falling back to `application/octet-stream`. |

## Command-line usage

Look up an entry or print dictionary keys without writing Swift code:

```sh
swift run mdict-cli --path /path/to/dictionary.mdx lookup hello
swift run mdict-cli --path /path/to/dictionary.mdx keys 20
```

Run `swift run mdict-cli --help` for the full command reference.

## Development

The C++ implementation is included as a Git submodule, and test dictionaries are managed with Git LFS:

```sh
git clone --recurse-submodules https://github.com/xinnjie/mdict-swift.git
cd mdict-swift
git lfs pull
swift test
```
