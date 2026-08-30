// Strings in Swift are collections of Characters, not of bytes, which is
// why indexing works the way it does.

import Foundation

let line = "Alder Cross,Amber,2,true"
let name = "Quill Wharf"

print("count:", name.count)
print("upper:", name.uppercased(), "| lower:", name.lowercased())
print("capitalized:", "quill moor station".capitalized)

print("contains:", line.contains("Amber"))
print("hasPrefix/hasSuffix:", line.hasPrefix("Alder"), line.hasSuffix("true"))
print("isEmpty:", "".isEmpty)

// Splitting and joining.
let fields = line.split(separator: ",").map(String.init)
print("\(fields.count) fields, last \(fields.last ?? "-")")
print("joined:", fields.prefix(3).joined(separator: " | "))
print("keeping empties:", "a,,b".split(separator: ",", omittingEmptySubsequences: false).count)

// String indices are opaque, because a Character can span several bytes.
let start = name.startIndex
let fifth = name.index(start, offsetBy: 5)
print("prefix:", name[start..<fifth])
print("suffix:", name[fifth...])
print("first/last:", name.first as Any, name.last as Any)
print("prefix(5):", name.prefix(5), "| suffix(5):", name.suffix(5))

if let comma = line.firstIndex(of: ",") {
    print("up to the comma:", line[..<comma])
    print("after it:", line[line.index(after: comma)...])
}

// Replacing and trimming.
print("replaced:", line.replacingOccurrences(of: ",", with: "; "))
print("trimmed: [\("   spaced out   ".trimmingCharacters(in: .whitespaces))]")
print("dropped:", line.dropFirst(12))

// Multibyte text: characters, unicode scalars, and UTF-8 bytes are three
// different counts.
let unicode = "café naïve"
print("characters \(unicode.count), scalars \(unicode.unicodeScalars.count), utf8 \(unicode.utf8.count)")
print("first four:", String(unicode.prefix(4)))

// A combining sequence is one Character even though it is several scalars.
let combined = "e\u{0301}"
print("\(combined) is \(combined.count) character of \(combined.unicodeScalars.count) scalars")

// Building strings.
var report = ""
for zone in 1...5 {
    report += "zone \(zone)"
    if zone < 5 { report += " -> " }
}
print(report)

print(String(repeating: "-", count: 24))
print(String(format: "%@ %5.2f %03d", "Alder Cross" as NSString, 3.4, 2))
print("padded: |\(name.padding(toLength: 20, withPad: " ", startingAt: 0))|")

// Multi-line literals keep the layout and strip the common indentation.
let block = """
    Station: \(name)
    Zone:    2
    """
print(block)

// Raw strings need no escaping, which suits regular expressions and paths.
print(#"a raw string keeps \n and "quotes" as they are"#)

// Parsing and formatting numbers.
print("parsed:", Int("2") as Any, "| bad parse:", Int("east") as Any)
print("formatted:", 1234567.891.formatted(.number.precision(.fractionLength(2))))

// A slug, using only the standard library.
let slug = line.lowercased()
    .map { $0.isLetter || $0.isNumber ? $0 : "-" }
    .reduce(into: "") { result, character in
        if character == "-" && result.hasSuffix("-") { return }
        result.append(character)
    }
print("slug:", slug.trimmingCharacters(in: CharacterSet(charactersIn: "-")))
