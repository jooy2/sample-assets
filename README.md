<img src=".github/resources/sample-assets-logo.webp" alt="sample-assets" width="112" height="112">

# sample-assets

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jooy2/sample-assets/blob/main/LICENSE) [![Validate datasets](https://github.com/jooy2/sample-assets/actions/workflows/validate-datasets.yml/badge.svg)](https://github.com/jooy2/sample-assets/actions/workflows/validate-datasets.yml) ![Repository size](https://img.shields.io/github/repo-size/jooy2/sample-assets) ![Commit Count](https://img.shields.io/github/commit-activity/y/jooy2/sample-assets) [![Followers](https://img.shields.io/github/followers/jooy2?style=social)](https://github.com/jooy2) ![Stars](https://img.shields.io/github/stars/jooy2/sample-assets?style=social)

**sample-assets** is a collection of sample material — data, code, images, video, audio,
documents, and prose — kept in one place so that a demo, a test, a tutorial, or a
prototype never stalls on the search for a file to feed it.

Every developer ends up with the same scattered pile: a CSV somewhere in Downloads, a
placeholder photo borrowed from a blog post, a PDF that happened to be lying around. This
repository is that pile, organized, named consistently, and free to redistribute.

> **The structure is in place, and the assets are being added over time.** Folders you
> find empty today are waiting for their content, not missing it.

## What's inside

| Folder                        | Holds                                                     | Organized by                                     |
| ----------------------------- | --------------------------------------------------------- | ------------------------------------------------ |
| [`datasets/`](datasets)       | Synthetic data for imports, fixtures, and parser tests     | File format, then topic                          |
| [`code/`](code)               | Source snippets and small self-contained programs          | Programming language                             |
| [`images/`](images)           | Photos, illustrations, and interface icons                 | Kind of image                                    |
| [`videos/`](videos)           | Short clips for players, thumbnails, and transcoding       | Flat                                             |
| [`audio/`](audio)             | Sounds, tones, and loops for players and waveform tests    | Flat                                             |
| [`documents/`](documents)     | PDFs, office files, and other document formats             | File format                                      |
| [`text/`](text)               | Long-form prose and verse as plain text, no markup         | Flat, genre in the file name                     |

Each folder carries its own `README.md` describing what belongs in it, which formats it
accepts, and how its files are named. Read that one before adding anything.

## Layout

```text
datasets/        Sample data. One subfolder per format:
  csv/             comma-separated values
  json/            JSON and JSON Lines
  sql/             dumps and seed scripts
  tsv/             tab-separated values
  txt/             plain text, log lines, word lists
  xml/             XML documents and feeds
  yaml/            YAML configuration and data
code/            Source code samples. One subfolder per language:
  c/  cpp/  csharp/  dart/  go/  java/  javascript/  kotlin/
  php/  python/  ruby/  rust/  shell/  swift/  typescript/
images/
  photos/          photographic images
  illustrations/   drawn artwork
  icons/           interface marks, preferably SVG
videos/          Short video clips
audio/           Sound files
documents/       Documents. One subfolder per format:
  adoc/  css/  docx/  epub/  html/  md/  odp/  ods/
  odt/  org/  pdf/  pptx/  rst/  rtf/  tex/  xlsx/
text/            Long-form plain text: stories, essays, reports, poems
```

## Datasets are indexed twice

Sample data is wanted in two different ways — *"I need a CSV"* and *"I need a list of
users"* — so `datasets/` answers both. **Folders are formats. File names are topics.** A
topic keeps the same name in every format it exists in:

```text
datasets/csv/users.csv     ┐
datasets/json/users.json   ├─ the same records, three ways
datasets/sql/users.sql     ┘
```

Pick the topic and you know the file name; pick the format and you know the folder. When
one topic comes in several sizes, the row count goes in the name — `users-100.csv`,
`users-10000.csv` — and a plain `users.csv` is always the small, quick-to-read one.

## Three folders hold text, for three different reasons

Plain text turns up in three places, and the difference is what the file *is*:

```text
datasets/txt/server-access-log.txt   data to parse
text/story-the-last-round.txt        prose to read
documents/md/readme-sample.md        a document, with markup
```

A log, a word list, or a fixture is data, whatever its extension. A story, a report, or
an essay is prose, and lives in `text/` with no markup at all. Writing that needs
headings, italics, or a page layout is a document.

## Using the assets

Clone the whole repository:

```bash
git clone https://github.com/jooy2/sample-assets.git
```

Or take only the folders you need, without downloading the rest:

```bash
git clone --filter=blob:none --sparse https://github.com/jooy2/sample-assets.git
```

```bash
git sparse-checkout set datasets/json images/icons
```

Grab a single file from the command line:

```bash
curl -O https://raw.githubusercontent.com/jooy2/sample-assets/main/datasets/json/users.json
```

Or link one straight into a page or a fixture, served by jsDelivr's CDN:

```text
https://cdn.jsdelivr.net/gh/jooy2/sample-assets@main/images/photos/mountain-lake.jpg
```

Pin `@main` to a tag or a commit hash when a sample must not change under you.

## Conventions

The rules are short, and each folder's `README.md` states its own specifics:

- **Lowercase `kebab-case` names**, describing the subject: `world-cities.csv`,
  `notification-ping.mp3`, `icon-download.svg`. Code is the exception — a sample there is
  named the way its own language names files, so `HelloWorld.java` stays `HelloWorld.java`.
- **Qualifiers go in the name**, not in a nested folder — a row count, a resolution, a
  duration, or the shape a sample exists to exercise: `users-nested.json`,
  `mountain-lake-1920x1080.jpg`, `silence-5s.wav`.
- **Deliberately broken samples say so**, with `-malformed`, `-invalid`, or `-broken` in
  the name. Those are the only files exempt from the format check in CI.
- **UTF-8 and LF**, unless a sample exists to demonstrate the opposite.
- **Files stay small.** A sample is meant to be cloned, not archived.

Everything under `datasets/` is checked on every push: it must parse as the format its
extension claims, sit in the matching folder, and follow the naming rule. Run the same
check locally before opening a pull request:

```bash
python3 .github/scripts/validate-datasets.py
```

## Generated content

Some of the assets in this collection are **produced by generative AI agents** — data
rows, illustrations, code samples, and document text among them. That is deliberate: a
sample invented for this repository can be handed to anyone, which is not true of material
borrowed from somewhere else.

None of it depicts or describes anything real. The people, faces, companies, products,
places, and events in these assets are **inventions rather than records**. They are not
based on any actual person, organization, or location, and **any resemblance to a real one
is coincidental**.

So treat a generated asset as a stand-in, not as a source. The figures in it are not
accurate, the text in it is not authoritative, and the code in it has not been reviewed for
production use.

## What does not belong here

- **Real personal data.** Sample records are invented. Names, addresses, and card numbers
  in this repository describe nobody.
- **Credentials**, live API keys, or anything scraped from a service that did not offer it.
- **Assets that are not free to redistribute.** If it cannot be handed to a stranger with
  its license attached, it cannot be here.

## Licensing and attribution

The repository and the assets created for it are released under the [MIT License](LICENSE).

An asset that comes from somewhere else keeps **its own license**, and is listed in its
folder's `README.md` with the source, the author, and the terms. Check that list before
shipping an asset in a product — MIT covers this collection, not necessarily every file
in it.

## Contributing

Anyone can contribute to the project by reporting new issues or submitting a pull request.
For more information, please see [CONTRIBUTING.md](CONTRIBUTING.md). Participation is
subject to the [Code of Conduct](CODE_OF_CONDUCT.md).

To report a security issue, or an asset that should not have been published, please follow
the process described in [SECURITY.md](SECURITY.md).

## Author

CDGet &lt;jooy2.contact@gmail.com&gt; · [cdget.com](https://cdget.com)

## License

Please see the [LICENSE](LICENSE) file for more information about project owners, usage
rights, and more.
