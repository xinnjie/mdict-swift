// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "mdict-swift",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
  ],
  products: [
    .library(
      name: "mdict-swift",
      targets: ["mdict-swift"])
  ],
  targets: [
    // Dependencies
    .target(
      name: "mdictminiz",
      path: "Sources/mdict-cpp/deps/miniz",
      exclude: [
        "examples", "tests", "amalgamate.sh", "test.sh", "CMakeLists.txt", "ChangeLog.md",
        "LICENSE", "readme.md", ".clang-format", ".travis.yml",
      ],
      sources: ["miniz.c", "miniz_zip.c", "miniz_tinfl.c", "miniz_tdef.c"],
      publicHeadersPath: ".",
      cSettings: [
        .define("MINIZ_NO_STDIO", to: nil),
        .define("_LARGEFILE64_SOURCE", to: "1"),
      ]
    ),
    .target(
      name: "mdictminilzo",
      path: "Sources/mdict-cpp/deps/minilzo",
      exclude: ["testmini.c", "Makefile", "README.LZO", "COPYING", "CMakeLists.txt"],
      sources: ["minilzo.c"],
      publicHeadersPath: "."
    ),
    .target(
      name: "mdictturbobase64",
      path: "Sources/mdict-cpp/deps/turbobase64",
      exclude: [
        "cmake", "rust", "vs", "tb64app.c", "tb64app", "makefile", "CMakeLists.txt", "LICENSE",
        "README.md", "time_.h",
      ],
      sources: ["turbob64c.c", "turbob64d.c", "turbob64v128.c"],
      publicHeadersPath: ".",
      cSettings: [
        .define("NAVX2"),
        .define("NAVX512"),
      ]
    ),

    // Main Target
    .target(
      name: "mdict",
      dependencies: ["mdictminiz", "mdictminilzo", "mdictturbobase64"],
      path: "Sources/mdict-cpp/src",
      exclude: ["mydict.cc"],
      sources: [
        "mdict.cc",
        "mdict_extern.cc",
        "binutils.cc",
        "adler32.cc",
        "ripemd128.c",
      ],
      publicHeadersPath: "include",
      cxxSettings: [
        .headerSearchPath("."),  // For internal includes
        .headerSearchPath("../deps"),  // For deps includes like "miniz/miniz.h"
        .define("MDICT_USE_MINIZ"),
      ]
    ),

    // Swift Wrapper
    .target(
      name: "mdict-swift",
      dependencies: ["mdict"],
      path: "Sources/mdict-swift",
      publicHeadersPath: "include"
    ),

    // Tests
    .testTarget(
      name: "mdict-swiftTests",
      dependencies: [
        "mdict-swift"
      ],
      path: "Tests/mdict-swiftTests",
      resources: [
        .copy("testdict.mdx")
      ]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
