# Datasets

Sample data for demos, prototypes, tutorials, fixtures, and import/export tests.

Everything here is **synthetic**. It looks like real data — names, addresses, orders,
log lines — but it describes nobody. No dataset in this folder may contain personal
data, credentials, or anything scraped from a live service.

## Layout

One subfolder per file format:

| Folder            | Format                    | Good for                                            |
| ----------------- | ------------------------- | --------------------------------------------------- |
| [`csv/`](csv)     | Comma-separated values    | Spreadsheet imports, data frames, bulk loaders      |
| [`json/`](json)   | JSON and JSON Lines       | API mocks, fixtures, document stores                |
| [`sql/`](sql)     | SQL dumps and seed scripts | Schema and seed data for relational databases       |
| [`tsv/`](tsv)     | Tab-separated values      | Anything that trips over commas inside fields       |
| [`txt/`](txt)     | Plain text                | Log lines, word lists, unstructured parsing samples |
| [`xml/`](xml)     | XML                       | Legacy interchange, feeds, SOAP-era payloads        |
| [`yaml/`](yaml)   | YAML                      | Configuration samples, human-edited data            |

Topics are not folders. A topic is a **file name**, and the same topic keeps the same
name in every format it exists in:

```text
datasets/csv/users.csv     ┐
datasets/json/users.json   ├─ the same 100 people, three ways
datasets/sql/users.sql     ┘
```

That way a topic can be picked first and a format second, without hunting through the
tree twice.

## Naming

- Lowercase, `kebab-case`, plural when the file holds a collection: `users.json`,
  `world-cities.csv`, `server-access-log.txt`.
- Add the row count when several sizes of one topic exist: `users-100.csv`,
  `users-10000.csv`. Without a suffix, a file is the small, quick-to-read version.
- Add a variant suffix when the point of the file is its shape rather than its topic:
  `users-nested.json`, `users-malformed.csv`, `users-utf8-bom.csv`.
- UTF-8, LF line endings, unless the file exists specifically to demonstrate the
  opposite — in which case say so in the name.

## Sources

Datasets written for this repository are covered by its [LICENSE](../LICENSE). A dataset
that comes from somewhere else keeps its own license, and is listed here with its source
and terms before it is added. Nothing has been added yet.
