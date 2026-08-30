# Code

Source code samples: snippets to paste into a demo, files to feed a syntax highlighter, a
linter, a formatter, or a parser, and small programs to show a language doing something.

## Layout

One subfolder per language, named after the language in lowercase:

| Folder                        | Language   | Extensions           |
| ----------------------------- | ---------- | -------------------- |
| [`c/`](c)                     | C          | `.c`, `.h`           |
| [`cpp/`](cpp)                 | C++        | `.cpp`, `.hpp`       |
| [`csharp/`](csharp)           | C#         | `.cs`                |
| [`dart/`](dart)               | Dart       | `.dart`              |
| [`go/`](go)                   | Go         | `.go`                |
| [`java/`](java)               | Java       | `.java`              |
| [`javascript/`](javascript)   | JavaScript | `.js`, `.mjs`, `.cjs` |
| [`kotlin/`](kotlin)           | Kotlin     | `.kt`                |
| [`php/`](php)                 | PHP        | `.php`               |
| [`python/`](python)           | Python     | `.py`                |
| [`ruby/`](ruby)               | Ruby       | `.rb`                |
| [`rust/`](rust)               | Rust       | `.rs`                |
| [`shell/`](shell)             | Shell      | `.sh`                |
| [`swift/`](swift)             | Swift      | `.swift`             |
| [`typescript/`](typescript)   | TypeScript | `.ts`                |

A language that has no folder yet gets one, named the same way. The folder is the
**language**, never the framework — a React component is a sample of JavaScript or
TypeScript, and says `react` in its file name instead.

## Naming

Code is the one place in this repository where names follow **the language's own
convention** rather than the repository's `kebab-case` rule, because some languages
enforce theirs: `HelloWorld.java` has to match its class, and `hello_world.py` is what a
Python module looks like.

Everything else still holds:

- Name the file after what the sample demonstrates: `fizzbuzz.py`, `BinarySearch.java`,
  `read-file-async.js`, `struct_traits.rs`.
- Add the qualifier to the name when the point is a variant: `sort-quick.go`,
  `sort-merge.go`, `fizzbuzz-recursive.py`.
- Mark a sample that is meant to be broken with `-invalid`, `-malformed`, or `-broken`,
  the same way datasets do. A file that will not compile on purpose has to say so.

## What belongs here

- **Self-contained files.** A sample should be readable on its own and run, compile, or at
  least parse without a project around it. No build scripts, no lockfiles, no vendored
  dependencies.
- **Short files.** A sample is read by a person or by a parser, not shipped.
- **Plain standard-library code**, unless the sample exists to show a specific library.

Markup and stylesheets are documents rather than programs, so `.html` and `.css` samples
live in [`documents/`](../documents), and SQL lives in
[`datasets/sql/`](../datasets/sql) with the rest of the data.

## Sources

Code written for this repository is covered by its [LICENSE](../LICENSE). A sample that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Nothing has been added yet.
