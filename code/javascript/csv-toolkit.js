/**
 * csv-toolkit.js — parse, query, reshape, and format tabular data.
 *
 * A complete RFC 4180 parser (quotes, embedded newlines, escaped quotes),
 * type inference, a small chainable query API, grouping and pivoting, and
 * writers for CSV, TSV, JSON, and fixed-width text tables.
 *
 * No dependencies. Runs in a browser or in Node.
 *
 *   const table = Table.fromCSV(text);
 *   table.where((row) => row.region === 'North')
 *        .orderBy('revenue', 'desc')
 *        .select('product', 'revenue')
 *        .toText();
 */

'use strict';

// -------------------------------------------------------------------- parser

/**
 * Parse delimiter-separated text into an array of string arrays.
 *
 * Handles the three things naive `split(',')` gets wrong: a delimiter inside
 * quotes, a newline inside quotes, and a doubled quote standing for a literal
 * one. Accepts LF, CRLF, and CR line endings.
 *
 * @param {string} text
 * @param {{delimiter?: string, quote?: string, trim?: boolean}} [options]
 * @returns {string[][]}
 */
function parseDelimited(text, options = {}) {
  const { delimiter = ',', quote = '"', trim = false } = options;

  if (delimiter.length !== 1) throw new Error('delimiter must be one character');
  if (quote.length !== 1) throw new Error('quote must be one character');

  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  let fieldWasQuoted = false;
  let index = 0;

  const pushField = () => {
    let value = field;
    if (trim && !fieldWasQuoted) value = value.trim();
    row.push(value);
    field = '';
    fieldWasQuoted = false;
  };

  const pushRow = () => {
    pushField();
    // A trailing newline should not produce a final empty row.
    if (row.length > 1 || row[0] !== '') rows.push(row);
    row = [];
  };

  while (index < text.length) {
    const char = text[index];

    if (inQuotes) {
      if (char === quote) {
        if (text[index + 1] === quote) {
          field += quote;
          index += 2;
          continue;
        }
        inQuotes = false;
        index += 1;
        continue;
      }
      field += char;
      index += 1;
      continue;
    }

    if (char === quote && field === '') {
      inQuotes = true;
      fieldWasQuoted = true;
      index += 1;
      continue;
    }

    if (char === delimiter) {
      pushField();
      index += 1;
      continue;
    }

    if (char === '\r') {
      pushRow();
      index += text[index + 1] === '\n' ? 2 : 1;
      continue;
    }

    if (char === '\n') {
      pushRow();
      index += 1;
      continue;
    }

    field += char;
    index += 1;
  }

  if (inQuotes) throw new SyntaxError('unterminated quoted field');
  if (field !== '' || row.length > 0) pushRow();

  return rows;
}

/** Quote a value for CSV output only when it needs quoting. */
function quoteField(value, delimiter = ',', quote = '"') {
  const text = value === null || value === undefined ? '' : String(value);
  const needsQuotes =
    text.includes(delimiter) ||
    text.includes(quote) ||
    text.includes('\n') ||
    text.includes('\r') ||
    text !== text.trim();

  if (!needsQuotes) return text;
  return quote + text.split(quote).join(quote + quote) + quote;
}

// ------------------------------------------------------------ type inference

const ISO_DATE = /^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?)?$/;
const NUMBER = /^-?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?$/;
const BOOLEAN = /^(?:true|false|yes|no|y|n)$/i;

/** Guess the type of a single cell. */
function inferCell(text) {
  const value = text.trim();
  if (value === '') return 'empty';
  if (BOOLEAN.test(value)) return 'boolean';
  if (NUMBER.test(value)) return 'number';
  if (ISO_DATE.test(value)) return 'date';
  return 'string';
}

/**
 * Guess a column's type from its cells. A column is only numeric if every
 * non-empty cell is; one stray label makes the whole column text, which is
 * the behaviour that avoids silently dropping data.
 */
function inferColumn(values) {
  const kinds = new Set(values.map(inferCell));
  kinds.delete('empty');
  if (kinds.size === 0) return 'string';
  if (kinds.size === 1) return [...kinds][0];
  return 'string';
}

/** Convert a cell according to a column type. */
function coerce(text, kind) {
  const value = text.trim();
  if (value === '') return null;

  switch (kind) {
    case 'number':
      return Number(value.replace(/,/g, ''));
    case 'boolean':
      return /^(?:true|yes|y)$/i.test(value);
    case 'date':
      return new Date(value.includes('T') ? value : `${value}T00:00:00Z`);
    default:
      return text;
  }
}

// --------------------------------------------------------------------- table

/** An immutable table: named columns, typed rows, and a chainable query API. */
class Table {
  /**
   * @param {string[]} columns
   * @param {Array<Object>} rows
   * @param {Record<string,string>} [types]
   */
  constructor(columns, rows, types = {}) {
    this.columns = Object.freeze([...columns]);
    this.rows = Object.freeze(rows.map((row) => Object.freeze({ ...row })));
    this.types = Object.freeze({ ...types });
  }

  get length() {
    return this.rows.length;
  }

  /** Build a table from delimited text, inferring column types. */
  static fromCSV(text, options = {}) {
    const { header = true, infer = true, ...parseOptions } = options;
    const grid = parseDelimited(text, { trim: true, ...parseOptions });
    if (grid.length === 0) return new Table([], []);

    const columns = header
      ? grid[0].map((name, index) => name || `column${index + 1}`)
      : grid[0].map((_, index) => `column${index + 1}`);
    const body = header ? grid.slice(1) : grid;

    const types = {};
    columns.forEach((name, index) => {
      types[name] = infer
        ? inferColumn(body.map((cells) => cells[index] ?? ''))
        : 'string';
    });

    const rows = body.map((cells) => {
      const row = {};
      columns.forEach((name, index) => {
        const cell = cells[index] ?? '';
        row[name] = infer ? coerce(cell, types[name]) : cell;
      });
      return row;
    });

    return new Table(columns, rows, types);
  }

  /** Build a table from an array of plain objects. */
  static fromObjects(objects) {
    const columns = [];
    for (const object of objects) {
      for (const key of Object.keys(object)) {
        if (!columns.includes(key)) columns.push(key);
      }
    }
    const types = {};
    for (const name of columns) {
      const sample = objects.map((o) => String(o[name] ?? ''));
      types[name] = inferColumn(sample);
    }
    return new Table(columns, objects, types);
  }

  // -------------------------------------------------------------- querying

  /** Keep the rows a predicate accepts. */
  where(predicate) {
    return new Table(this.columns, this.rows.filter(predicate), this.types);
  }

  /** Keep only the named columns, in the order given. */
  select(...names) {
    const wanted = names.flat();
    const missing = wanted.filter((name) => !this.columns.includes(name));
    if (missing.length) throw new Error(`no such column: ${missing.join(', ')}`);

    const rows = this.rows.map((row) => {
      const out = {};
      for (const name of wanted) out[name] = row[name];
      return out;
    });
    const types = {};
    for (const name of wanted) types[name] = this.types[name];
    return new Table(wanted, rows, types);
  }

  /** Add or replace a column computed from each row. */
  derive(name, compute) {
    const rows = this.rows.map((row, index) => ({
      ...row,
      [name]: compute(row, index),
    }));
    const columns = this.columns.includes(name)
      ? [...this.columns]
      : [...this.columns, name];
    const types = {
      ...this.types,
      [name]: inferColumn(rows.map((row) => String(row[name] ?? ''))),
    };
    return new Table(columns, rows, types);
  }

  /** Sort by a column or by a key function. Dates and numbers sort naturally. */
  orderBy(key, direction = 'asc') {
    const extract = typeof key === 'function' ? key : (row) => row[key];
    const sign = direction === 'desc' ? -1 : 1;

    const rows = [...this.rows].sort((a, b) => {
      const left = extract(a);
      const right = extract(b);
      if (left === right) return 0;
      if (left === null || left === undefined) return 1;
      if (right === null || right === undefined) return -1;
      if (left instanceof Date && right instanceof Date) {
        return sign * (left.getTime() - right.getTime());
      }
      if (typeof left === 'number' && typeof right === 'number') {
        return sign * (left - right);
      }
      return sign * String(left).localeCompare(String(right));
    });

    return new Table(this.columns, rows, this.types);
  }

  limit(count, offset = 0) {
    return new Table(this.columns, this.rows.slice(offset, offset + count), this.types);
  }

  /** Distinct rows by a key function, keeping the first of each. */
  distinct(key = (row) => JSON.stringify(row)) {
    const seen = new Set();
    const rows = [];
    for (const row of this.rows) {
      const identity = key(row);
      if (seen.has(identity)) continue;
      seen.add(identity);
      rows.push(row);
    }
    return new Table(this.columns, rows, this.types);
  }

  // ------------------------------------------------------------- aggregate

  /**
   * Group rows and aggregate each group.
   *
   * @param {string|string[]} by
   * @param {Record<string, (rows: object[]) => any>} aggregates
   */
  groupBy(by, aggregates) {
    const keys = Array.isArray(by) ? by : [by];
    const groups = new Map();

    for (const row of this.rows) {
      const identity = keys.map((k) => String(row[k])).join(' ');
      if (!groups.has(identity)) groups.set(identity, []);
      groups.get(identity).push(row);
    }

    const rows = [];
    for (const members of groups.values()) {
      const out = {};
      for (const key of keys) out[key] = members[0][key];
      for (const [name, fn] of Object.entries(aggregates)) out[name] = fn(members);
      rows.push(out);
    }

    return Table.fromObjects(rows);
  }

  /**
   * Reshape long data into a grid: one row per `rowKey` value, one column per
   * `columnKey` value.
   */
  pivot(rowKey, columnKey, valueKey, aggregate = sum) {
    const columnValues = [
      ...new Set(this.rows.map((row) => String(row[columnKey]))),
    ].sort();
    const rowValues = [...new Set(this.rows.map((row) => String(row[rowKey])))].sort();

    const cells = new Map();
    for (const row of this.rows) {
      const identity = `${row[rowKey]} ${row[columnKey]}`;
      if (!cells.has(identity)) cells.set(identity, []);
      cells.get(identity).push(row[valueKey]);
    }

    const out = rowValues.map((value) => {
      const record = { [rowKey]: value };
      for (const column of columnValues) {
        const bucket = cells.get(`${value} ${column}`);
        record[column] = bucket ? aggregate(bucket.map((v) => ({ v }))) : null;
      }
      return record;
    });

    // Built directly rather than via fromObjects so that the column order
    // follows the sorted column values rather than first-seen order.
    const columns = [rowKey, ...columnValues];
    const types = {};
    for (const name of columns) {
      types[name] = inferColumn(out.map((record) => String(record[name] ?? '')));
    }
    return new Table(columns, out, types);
  }

  /** Inner join on a shared key. */
  join(other, on, { prefix = '' } = {}) {
    const index = new Map();
    for (const row of other.rows) {
      const identity = String(row[on]);
      if (!index.has(identity)) index.set(identity, []);
      index.get(identity).push(row);
    }

    const rows = [];
    for (const left of this.rows) {
      const matches = index.get(String(left[on])) ?? [];
      for (const right of matches) {
        const merged = { ...left };
        for (const [key, value] of Object.entries(right)) {
          if (key === on) continue;
          merged[prefix + key] = value;
        }
        rows.push(merged);
      }
    }

    return Table.fromObjects(rows);
  }

  /** Descriptive statistics for the numeric columns. */
  describe() {
    const rows = [];
    for (const name of this.columns) {
      if (this.types[name] !== 'number') continue;
      const values = this.rows
        .map((row) => row[name])
        .filter((value) => typeof value === 'number' && Number.isFinite(value));
      if (values.length === 0) continue;

      const sorted = [...values].sort((a, b) => a - b);
      const total = values.reduce((a, b) => a + b, 0);
      const average = total / values.length;
      const variance =
        values.reduce((acc, value) => acc + (value - average) ** 2, 0) / values.length;

      rows.push({
        column: name,
        count: values.length,
        min: sorted[0],
        median: quantile(sorted, 0.5),
        mean: round(average, 4),
        max: sorted[sorted.length - 1],
        stdev: round(Math.sqrt(variance), 4),
      });
    }
    return Table.fromObjects(rows);
  }

  // --------------------------------------------------------------- output

  toObjects() {
    return this.rows.map((row) => ({ ...row }));
  }

  toCSV({ delimiter = ',', header = true, eol = '\n' } = {}) {
    const lines = [];
    if (header) {
      lines.push(this.columns.map((c) => quoteField(c, delimiter)).join(delimiter));
    }
    for (const row of this.rows) {
      lines.push(
        this.columns
          .map((name) => quoteField(format(row[name]), delimiter))
          .join(delimiter)
      );
    }
    return lines.join(eol);
  }

  toTSV(options = {}) {
    return this.toCSV({ delimiter: '	', ...options });
  }

  toJSON(indent = 2) {
    return JSON.stringify(this.toObjects(), null, indent);
  }

  /** A fixed-width text table, numbers right-aligned. */
  toText({ max = Infinity } = {}) {
    const shown = this.rows.slice(0, max);
    const widths = this.columns.map((name) =>
      Math.max(name.length, ...shown.map((row) => format(row[name]).length), 3)
    );

    const line = (cells) =>
      cells
        .map((cell, index) =>
          this.types[this.columns[index]] === 'number'
            ? cell.padStart(widths[index])
            : cell.padEnd(widths[index])
        )
        .join('  ');

    const out = [
      line(this.columns),
      widths.map((width) => '-'.repeat(width)).join('  '),
      ...shown.map((row) => line(this.columns.map((name) => format(row[name])))),
    ];

    if (shown.length < this.rows.length) {
      out.push(`... ${this.rows.length - shown.length} more row(s)`);
    }
    return out.join('\n');
  }
}

// ----------------------------------------------------------------- utilities

const sum = (rows, key = 'v') =>
  rows.reduce((total, row) => total + (Number(row[key]) || 0), 0);

const count = (rows) => rows.length;

const mean = (rows, key) => (rows.length ? sum(rows, key) / rows.length : 0);

const maxOf = (rows, key) => Math.max(...rows.map((row) => Number(row[key]) || 0));

function quantile(sorted, fraction) {
  if (sorted.length === 0) return null;
  const position = (sorted.length - 1) * fraction;
  const lower = Math.floor(position);
  const upper = Math.ceil(position);
  if (lower === upper) return sorted[lower];
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

const round = (value, places) => Number(value.toFixed(places));

function format(value) {
  if (value === null || value === undefined) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === 'number') {
    return Number.isInteger(value) ? String(value) : String(round(value, 2));
  }
  return String(value);
}

// ------------------------------------------------------------- demonstration

const SAMPLE = `region,product,quarter,units,revenue,launched
North,"Rope, 24mm",Q1,140,4830.00,2024-03-11
North,"Rope, 24mm",Q2,162,5589.00,2024-03-11
North,Lantern,Q1,88,7920.00,2025-06-02
North,Lantern,Q2,104,9360.00,2025-06-02
South,"Rope, 24mm",Q1,96,3312.00,2024-03-11
South,"Rope, 24mm",Q2,71,2449.50,2024-03-11
South,Lantern,Q1,142,12780.00,2025-06-02
South,Lantern,Q2,151,13590.00,2025-06-02
East,Lantern,Q1,45,4050.00,2025-06-02
East,Lantern,Q2,63,5670.00,2025-06-02
East,"Fender ""medium""",Q1,210,9345.00,2023-11-20
West,"Fender ""medium""",Q1,188,8366.00,2023-11-20
West,"Fender ""medium""",Q2,204,9078.00,2023-11-20
West,Lantern,Q2,97,8730.00,2025-06-02
`;

function demonstrate() {
  const table = Table.fromCSV(SAMPLE);

  console.log('--- inferred types ---');
  console.log(table.columns.map((name) => `${name}: ${table.types[name]}`).join('\n'));

  console.log('\n--- quoted fields survived ---');
  console.log([...new Set(table.rows.map((row) => row.product))].join(' | '));

  console.log('\n--- top five by revenue ---');
  console.log(
    table
      .select('region', 'product', 'quarter', 'revenue')
      .orderBy('revenue', 'desc')
      .limit(5)
      .toText()
  );

  console.log('\n--- revenue by region ---');
  console.log(
    table
      .groupBy('region', {
        rows: count,
        units: (rows) => sum(rows, 'units'),
        revenue: (rows) => round(sum(rows, 'revenue'), 2),
        best: (rows) => maxOf(rows, 'revenue'),
      })
      .orderBy('revenue', 'desc')
      .toText()
  );

  console.log('\n--- product by quarter (pivot) ---');
  console.log(table.pivot('product', 'quarter', 'revenue').toText());

  console.log('\n--- derived column ---');
  console.log(
    table
      .where((row) => row.region === 'North')
      .derive('unitPrice', (row) => round(row.revenue / row.units, 2))
      .select('product', 'quarter', 'units', 'revenue', 'unitPrice')
      .toText()
  );

  console.log('\n--- describe ---');
  console.log(table.describe().toText());

  console.log('\n--- join ---');
  const catalogue = Table.fromObjects([
    { product: 'Lantern', category: 'Deck' },
    { product: 'Rope, 24mm', category: 'Deck' },
    { product: 'Fender "medium"', category: 'Fendering' },
  ]);
  console.log(
    table
      .join(catalogue, 'product')
      .groupBy('category', { revenue: (rows) => round(sum(rows, 'revenue'), 2) })
      .orderBy('revenue', 'desc')
      .toText()
  );

  console.log('\n--- round trip ---');
  const written = table.limit(3).toCSV();
  console.log(written);
  const reread = Table.fromCSV(written);
  console.log('rows match:', reread.length === 3);
  console.log('quoting preserved:', reread.rows[0].product === table.rows[0].product);

  console.log('\n--- awkward input ---');
  const awkward = 'a,b\n"line\none",2\n"say ""hi""",3\n,4\n';
  const parsed = Table.fromCSV(awkward);
  console.log(JSON.stringify(parsed.toObjects()));

  try {
    Table.fromCSV('a,b\n"unterminated,2\n');
  } catch (error) {
    console.log('rejected:', error.constructor.name, '-', error.message);
  }
}

// ------------------------------------------------------------------- exports

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    Table,
    parseDelimited,
    quoteField,
    inferCell,
    inferColumn,
    coerce,
    sum,
    count,
    mean,
    maxOf,
    quantile,
  };
}

if (typeof require !== 'undefined' && require.main === module) {
  demonstrate();
}
