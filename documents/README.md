# Documents

Document files for viewers, parsers, text extraction, conversion, and upload tests.

## Layout

One subfolder per format, named after the extension it holds:

| Folder            | Format                          | Extension | Kind   |
| ----------------- | ------------------------------- | --------- | ------ |
| [`adoc/`](adoc)   | AsciiDoc                        | `.adoc`   | text   |
| [`css/`](css)     | Cascading style sheets          | `.css`    | text   |
| [`docx/`](docx)   | Word (Office Open XML)          | `.docx`   | binary |
| [`html/`](html)   | HTML pages                      | `.html`   | text   |
| [`md/`](md)       | Markdown                        | `.md`     | text   |
| [`ods/`](ods)     | OpenDocument spreadsheet        | `.ods`    | binary |
| [`odt/`](odt)     | OpenDocument text               | `.odt`    | binary |
| [`org/`](org)     | Org mode                        | `.org`    | text   |
| [`pdf/`](pdf)     | PDF                             | `.pdf`    | binary |
| [`pptx/`](pptx)   | PowerPoint (Office Open XML)    | `.pptx`   | binary |
| [`rst/`](rst)     | reStructuredText                | `.rst`    | text   |
| [`rtf/`](rtf)     | Rich Text Format                | `.rtf`    | text   |
| [`tex/`](tex)     | LaTeX                           | `.tex`    | text   |
| [`xlsx/`](xlsx)   | Excel (Office Open XML)         | `.xlsx`   | binary |

**Folders are formats. File names are topics** — the same rule `datasets/` follows. A
topic keeps the same name in every format it exists in, so `documents/docx/meeting-notes.docx`
and `documents/odt/meeting-notes.odt` are the same document twice, and picking either the
topic or the format tells you where to look.

A format that has no folder yet gets one, named after its extension in lowercase, and a
line in the table above.

## Naming

- Lowercase, `kebab-case`, describing the document: `invoice-sample.pdf`,
  `meeting-notes.docx`, `budget-planner.xlsx`.
- Add the feature under test when that is the reason the file exists:
  `form-fillable.pdf`, `spreadsheet-with-formulas.xlsx`, `slides-with-notes.pptx`.
- Add the page, sheet, slide, or chapter count for large files: `manual-20pages.pdf`,
  `training-deck-10slides.pptx`.
- The extension is not repeated in the name. The folder already says it.

## Size

A document is meant to be opened, not archived. Keep text formats under 100 KB and binary
ones under 1 MB; a sample that exists to be large says so in its name and says why in the
commit that adds it.

## Passwords

One sample is encrypted on purpose. `pdf/report-password-protected.pdf` opens with the
user password `sample`, and its permission flags are held by the owner password
`sample-owner`. A sample that locks something says so here — nothing in this folder
protects anything worth protecting.

## Contents

Every document is fictional. No real invoices, contracts, résumés, or correspondence —
even redacted. If a sample needs a company, an address, or a person, invent one.

## Sources

Documents written for this repository are covered by its [LICENSE](../LICENSE). A document
that comes from somewhere else keeps its own license, and is listed here with its source
and terms before it is added. Nothing has been added yet.
