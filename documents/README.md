# Documents

Document files for viewers, parsers, text extraction, conversion, and upload tests.

## Formats

`.pdf`, `.docx`, `.xlsx`, `.pptx`, `.odt`, `.rtf`, `.md`, `.html`. A document that exists
to exercise a specific feature — a form, an embedded font, a scanned page needing OCR, a
password-protected file — belongs here too, with that feature in its name.

## Naming

- Lowercase, `kebab-case`, describing the document: `invoice-sample.pdf`,
  `meeting-notes.docx`, `monthly-report.xlsx`.
- Add the feature under test when that is the reason the file exists:
  `invoice-sample-scanned.pdf`, `form-fillable.pdf`, `spreadsheet-with-formulas.xlsx`.
- Add the page or sheet count for large files: `manual-120pages.pdf`.

## Contents

Every document is fictional. No real invoices, contracts, résumés, or correspondence —
even redacted. If a sample needs a company, an address, or a person, invent one.

## Sources

Documents written for this repository are covered by its [LICENSE](../LICENSE). A document
that comes from somewhere else keeps its own license, and is listed here with its source
and terms before it is added. Nothing has been added yet.
