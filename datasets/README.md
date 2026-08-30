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
datasets/json/users.json   ├─ the same 120 people, three ways
datasets/sql/users.sql     ┘
```

That way a topic can be picked first and a format second, without hunting through the
tree twice.

## Topics

Ten topics so far. Every one of them is the same records in each format it lists, so a
format can be swapped without the data changing underneath.

| Topic               | Records | Formats                        | Holds                                                               |
| ------------------- | ------: | ------------------------------ | ------------------------------------------------------------------- |
| `users`             |     120 | csv, tsv, json, sql, xml, yaml | People with contact details, sign-up dates, and account status      |
| `products`          |     200 | csv, json, sql, xml, yaml      | A retail catalogue: SKUs, prices, stock, ratings, tags              |
| `orders`            |     300 | csv, tsv, json, sql, xml       | Order headers with totals that actually add up                      |
| `employees`         |     150 | csv, json, sql, xml, yaml      | An org chart: departments, titles, salaries, `manager_id`           |
| `books`             |     180 | csv, tsv, json, sql, xml       | A library catalogue of invented titles, authors, and publishers     |
| `recipes`           |      60 | json, xml, yaml                | Nested records: an ingredient list and ordered steps per recipe     |
| `sensor-readings`   |     500 | csv, tsv, jsonl, sql           | Hourly telemetry from ten devices — a time series with outliers     |
| `server-access-log` |     400 | txt, csv, jsonl                | HTTP requests, as combined-log lines and as parsed fields           |
| `support-tickets`   |     150 | csv, tsv, json, sql, xml       | Helpdesk tickets whose free text carries commas and quotation marks |
| `transit-stations`  |      90 | csv, json, sql, xml, yaml      | Stations on an invented metro network, placed on a grid             |

Four of them line up, so they can be loaded together and joined:

```text
orders.user_id           -> users.id
support-tickets.user_id  -> users.id
support-tickets.assignee -> employees.email          (Customer Support only)
employees.manager_id     -> employees.employee_id
```

`orders.shipping_city` matches the city on the user who placed the order, and every
`sensor-readings` device keeps to the climate of the site it sits in — so a query that
groups or joins these files returns something sensible rather than noise.

Each format carries the record in the shape that format is good at. Lists (`tags`,
`ingredients`, `steps`) nest in JSON, YAML, and XML; in CSV, TSV, and SQL the scalar
lists collapse to a `;`-separated string, booleans read `true`/`false` in the text
formats and `1`/`0` in SQL, and an empty cell is a `NULL`.

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
