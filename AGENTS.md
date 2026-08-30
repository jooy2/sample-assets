# sample-assets

Guidance for AI agents (and humans) working in this repository. Written in English to
match the repo's existing docs (`README.md`, `CONTRIBUTING.md`).

## What this repository is

A **resource repository**, not a software project. It collects sample material — data,
code, images, video, audio, documents — that other work can borrow: fixtures for tests,
placeholder content for mockups, input files for parsers and importers.

The code samples are material too. `code/` holds snippets and small programs to be read,
highlighted, or parsed by something else; it is not this repository's own source.

There is nothing to build, install, or run. The only executable in the tree is
`.github/scripts/validate-datasets.py`, which checks the sample data.

The assets themselves are added over time. A folder that is empty is waiting for content,
so do not treat it as dead and do not delete it.

## Layout

```text
datasets/        Sample data, one subfolder per format: csv, json, sql, tsv, txt, xml, yaml
code/            Source code samples, one subfolder per language
images/          photos/, illustrations/, icons/
videos/          Short video clips
audio/           Sound files
documents/       PDFs and office documents
.github/         Issue and pull request templates, the dataset validation workflow
```

Every top-level folder has its own `README.md` stating which formats it takes and how its
files are named. **Read that file before adding to a folder**; it is more specific than
this one, and it is what a contributor is asked to follow.

## Where an asset goes

- Sort by **what the file is**, not by what it is for. A JSON file used as an icon
  manifest is still data, and belongs in `datasets/json/`.
- Under `datasets/`, folders are **formats** and file names are **topics**. The same topic
  keeps the same name in every format it exists in, so `datasets/csv/users.csv` and
  `datasets/json/users.json` hold the same records. Do not add topic folders.
- Everywhere else, qualifiers live in the file name rather than in a nested folder: a row
  count, a resolution, a duration, or the shape a sample exists to exercise
  (`users-10000.csv`, `mountain-lake-1920x1080.jpg`, `silence-5s.wav`,
  `users-nested.json`).
- Under `code/`, folders are **languages**, never frameworks or projects. A React sample
  is JavaScript or TypeScript with `react` in its file name.
- Names are lowercase `kebab-case`, restricted to `a-z`, `0-9`, `-`, and `.` — except
  under `code/`, where a file is named the way its own language names files
  (`HelloWorld.java`, `hello_world.py`). Do not rename a sample into `kebab-case` when the
  language will not compile it under that name.
- Markup, stylesheets, and SQL are sorted by what they are rather than by being code:
  `.html` and `.css` go to `documents/`, SQL goes to `datasets/sql/`.

## Hard rules

These are not style preferences. A change that breaks one of them does not get merged.

1. **Sample data is synthetic.** No real personal data, no credentials or live API keys,
   nothing scraped from a service that did not offer it. If a sample needs a person, a
   company, or an address, invent one.
2. **Every asset must be free to redistribute.** An asset that is not original work keeps
   its own license and is listed in its folder's `README.md` with its source, author, and
   terms — in the same change that adds it. The repository's MIT license covers the
   collection, not a file that arrived under different terms.
3. **Files stay small.** Git keeps every version of a binary in full, so a large file
   replaced twice lives in the history three times. The folder READMEs give per-type
   ceilings; when a large file is unavoidable, say why in the commit.
4. **Do not fabricate binary assets.** An agent can write a CSV or a JSON file. It cannot
   produce a photograph, a video, or a recording, and a placeholder generated to fill the
   gap is worse than an empty folder. Ask instead.

## The dataset validator

`.github/scripts/validate-datasets.py` walks `datasets/` and checks that each file parses
as the format its extension claims, sits in the matching format folder, decodes as UTF-8,
and follows the naming rule. CI runs it on any push or pull request that touches
`datasets/`. Run it yourself before committing sample data:

```bash
python3 .github/scripts/validate-datasets.py
```

It exits 0 on an empty tree, and YAML checking is skipped when PyYAML is not installed
locally — CI installs it. Files whose names contain `-malformed`, `-invalid`, or `-broken`
are checked for name and location but never for content, because breaking a parser is the
reason those samples exist.

## Changes that touch more than one file

- **Adding a format folder under `datasets/`** means five edits, not one: the folder and
  its `.gitkeep`, the format table in `datasets/README.md`, the tree in `README.md`,
  `FOLDER_EXTENSIONS` in `.github/scripts/validate-datasets.py`, and the extension's line
  in `.gitattributes` so its line endings and binary-ness are declared.
- **Adding a language folder under `code/`** means the folder and its `.gitkeep`, the
  language table in `code/README.md`, the language list in the `README.md` tree, and the
  extension's line in `.gitattributes`.
- **Adding a top-level category** means the folder, a `README.md` for it written like the
  existing ones, and both the category table and the tree in `README.md`.
- **Adding a file type that is new to the repository** means a line in `.gitattributes`.
  Text formats are normalized to LF; everything else is marked `binary`.
- Media extensions are deliberately **absent** from `.gitignore`. Media is the content
  here. Do not copy an ignore list from a code project into this one.

## Commit conventions

Follow the existing history: `tag: message`, in English, in the imperative.

- **tag** (Udacity Git style): `feat`, `fix`, `docs`, `style`, `refactor`, `test`,
  `chore`; plus the informal `package` (repository and GitHub configuration) and `typo`.
- In this repository, `feat` is what adds or updates assets, and `chore` is what moves
  folders around.
- Wrap paths and file names in backticks. Add `(fixes #1)` when an issue tracks the change.
- One logical change per commit. Adding three unrelated datasets is three commits; adding
  one topic in four formats is one.

Examples:

```text
feat: add a `users` dataset in `csv`, `json`, and `sql`
fix: correct the row count in `datasets/csv/world-cities.csv`
docs: describe the icon naming rule in `images/README.md`
package: run the dataset validation workflow on pull requests
```
