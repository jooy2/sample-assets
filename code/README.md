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

## Two sizes

Each language folder holds samples of two sizes, and both are wanted:

- **Snippets** — one construct each, a screen or two long: `closures-counter.js`,
  `SwitchExpressions.java`, `pattern_matching.rb`. These are what a syntax highlighter,
  a formatter, or a tutorial wants.
- **Programs** — a few hundred to a thousand lines, doing something whole:
  `lisp_interpreter.py`, `MazeSolver.java`, `query-builder.php`. These are what an
  indexer, a static analyser, a diff viewer, or a context-window test wants, and they
  are the only samples that show a language's constructs used *together*.

Two programs per language is the target. They are named after what they do, not after
their size — a reader can tell them apart by opening one.

## What belongs here

- **Self-contained files.** A sample should be readable on its own and run, compile, or at
  least parse without a project around it. No build scripts, no lockfiles, no vendored
  dependencies. This holds for the long programs too: each is one file with an entry
  point and, where the language has a convention for it, its own tests.
- **Plain standard-library code**, unless the sample exists to show a specific library.
- **A header comment** on a program saying what it does and how to run it. A snippet
  rarely needs one; a program always does.

Markup and stylesheets are documents rather than programs, so `.html` and `.css` samples
live in [`documents/`](../documents), and SQL lives in
[`datasets/sql/`](../datasets/sql) with the rest of the data.

## Sources

Code written for this repository is covered by its [LICENSE](../LICENSE). A sample that
comes from somewhere else keeps its own license, and is listed here with its source,
author, and terms before it is added. Nothing has been added yet.
