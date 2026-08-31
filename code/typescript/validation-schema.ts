/**
 * validation-schema.ts — a runtime validator whose types are inferred from the
 * schema, so a parsed value is typed without a second declaration.
 *
 * Generics, conditional and mapped types, template literal types, variadic
 * tuple types, discriminated unions, type predicates, and `satisfies`.
 *
 *   npx tsx validation-schema.ts
 *   node validation-schema.ts        # Node 22.6+, types stripped at load
 *
 * The point of the exercise is this: declare the shape once,
 *
 *   const Sailing = object({ id: string(), seats: number().int().min(0) });
 *   type Sailing = Infer<typeof Sailing>;
 *
 * and `Sailing` is `{ id: string; seats: number }` without anyone writing it.
 *
 * No dependencies. Everything below is one file.
 */

// --------------------------------------------------------------- the result

export type Issue = {
  readonly path: ReadonlyArray<string | number>;
  readonly message: string;
  readonly code:
    | 'invalid_type'
    | 'too_small'
    | 'too_large'
    | 'invalid_format'
    | 'unrecognised_key'
    | 'invalid_union'
    | 'custom';
};

export type Result<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly issues: ReadonlyArray<Issue> };

/** Narrows a Result to its success branch. */
export function isOk<T>(result: Result<T>): result is { ok: true; value: T } {
  return result.ok;
}

class ValidationError extends Error {
  readonly issues: ReadonlyArray<Issue>;

  constructor(issues: ReadonlyArray<Issue>) {
    super(
      `${issues.length} validation issue(s):\n` +
        issues.map((issue) => `  ${formatPath(issue.path)}: ${issue.message}`).join('\n'),
    );
    this.name = 'ValidationError';
    this.issues = issues;
  }
}

function formatPath(path: ReadonlyArray<string | number>): string {
  if (path.length === 0) return '(root)';
  return path
    .map((segment, index) =>
      typeof segment === 'number'
        ? `[${segment}]`
        : index === 0
          ? segment
          : `.${segment}`,
    )
    .join('');
}

// ---------------------------------------------------------------- the base

type Check<T> = (value: T, path: ReadonlyArray<string | number>) => Issue | null;

/**
 * A schema knows how to turn an unknown value into a T, or into a list of
 * reasons why it could not. The phantom `_type` is what carries T through
 * `Infer`; it is never assigned at runtime.
 */
export abstract class Schema<T> {
  declare readonly _type: T;

  protected checks: ReadonlyArray<Check<T>> = [];

  /** Every schema implements this; the refinements are applied around it. */
  protected abstract parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<T>;

  safeParse(value: unknown, path: ReadonlyArray<string | number> = []): Result<T> {
    const base = this.parseValue(value, path);
    if (!base.ok) return base;

    const issues: Issue[] = [];
    for (const check of this.checks) {
      const issue = check(base.value, path);
      if (issue) issues.push(issue);
    }
    return issues.length ? { ok: false, issues } : base;
  }

  /** Parse or throw. Useful at a boundary where a failure is a bug. */
  parse(value: unknown): T {
    const result = this.safeParse(value);
    if (!result.ok) throw new ValidationError(result.issues);
    return result.value;
  }

  /** Add an arbitrary predicate. */
  refine(predicate: (value: T) => boolean, message: string): this {
    const next = Object.create(this) as this;
    next.checks = [
      ...this.checks,
      (value, path) =>
        predicate(value) ? null : { path, message, code: 'custom' as const },
    ];
    return next;
  }

  /** Allow undefined as well as T. */
  optional(): OptionalSchema<T> {
    return new OptionalSchema(this);
  }

  /** Allow null as well as T. */
  nullable(): NullableSchema<T> {
    return new NullableSchema(this);
  }

  /** Substitute a value when the input is undefined. */
  withDefault(fallback: T): DefaultSchema<T> {
    return new DefaultSchema(this, fallback);
  }

  /** Map a valid value to something else, keeping the new type. */
  transform<U>(fn: (value: T) => U): TransformSchema<T, U> {
    return new TransformSchema(this, fn);
  }

  describe(): string {
    return this.constructor.name.replace(/Schema$/, '').toLowerCase();
  }
}

/** The static type a schema produces. */
export type Infer<S> = S extends Schema<infer T> ? T : never;

function typeIssue(
  expected: string,
  value: unknown,
  path: ReadonlyArray<string | number>,
): Issue {
  const actual = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
  return {
    path,
    message: `expected ${expected}, received ${actual}`,
    code: 'invalid_type',
  };
}

// ------------------------------------------------------------- primitives

class StringSchema extends Schema<string> {
  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<string> {
    return typeof value === 'string'
      ? { ok: true, value }
      : { ok: false, issues: [typeIssue('a string', value, path)] };
  }

  min(length: number): this {
    return this.addCheck(
      (value) => value.length >= length,
      `must be at least ${length} character(s)`,
      'too_small',
    );
  }

  max(length: number): this {
    return this.addCheck(
      (value) => value.length <= length,
      `must be at most ${length} character(s)`,
      'too_large',
    );
  }

  matches(pattern: RegExp, description = `must match ${pattern}`): this {
    return this.addCheck((value) => pattern.test(value), description, 'invalid_format');
  }

  email(): this {
    return this.matches(/^[^\s@]+@[^\s@]+\.[^\s@]+$/, 'must be an email address');
  }

  isoDate(): this {
    return this.addCheck(
      (value) => /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value)),
      'must be a date as YYYY-MM-DD',
      'invalid_format',
    );
  }

  private addCheck(
    predicate: (value: string) => boolean,
    message: string,
    code: Issue['code'],
  ): this {
    const next = Object.create(this) as this;
    next.checks = [
      ...this.checks,
      (value, path) => (predicate(value) ? null : { path, message, code }),
    ];
    return next;
  }
}

class NumberSchema extends Schema<number> {
  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<number> {
    // NaN is a number to `typeof` and to nobody else.
    return typeof value === 'number' && Number.isFinite(value)
      ? { ok: true, value }
      : { ok: false, issues: [typeIssue('a finite number', value, path)] };
  }

  int(): this {
    return this.addCheck(Number.isInteger, 'must be a whole number', 'invalid_format');
  }

  min(bound: number): this {
    return this.addCheck((value) => value >= bound, `must be at least ${bound}`, 'too_small');
  }

  max(bound: number): this {
    return this.addCheck((value) => value <= bound, `must be at most ${bound}`, 'too_large');
  }

  private addCheck(
    predicate: (value: number) => boolean,
    message: string,
    code: Issue['code'],
  ): this {
    const next = Object.create(this) as this;
    next.checks = [
      ...this.checks,
      (value, path) => (predicate(value) ? null : { path, message, code }),
    ];
    return next;
  }
}

class BooleanSchema extends Schema<boolean> {
  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<boolean> {
    return typeof value === 'boolean'
      ? { ok: true, value }
      : { ok: false, issues: [typeIssue('a boolean', value, path)] };
  }
}

/**
 * A set of allowed strings. The generic is a tuple of literal types, so
 * `literal('a', 'b')` produces `Schema<'a' | 'b'>` rather than
 * `Schema<string>`.
 */
class LiteralSchema<const T extends ReadonlyArray<string>> extends Schema<T[number]> {
  private readonly allowed: T;

  constructor(allowed: T) {
    super();
    this.allowed = allowed;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<T[number]> {
    if (typeof value === 'string' && (this.allowed as ReadonlyArray<string>).includes(value)) {
      return { ok: true, value: value as T[number] };
    }
    return {
      ok: false,
      issues: [
        {
          path,
          message: `must be one of: ${this.allowed.join(', ')}`,
          code: 'invalid_format',
        },
      ],
    };
  }

  override describe(): string {
    return this.allowed.map((value) => `"${value}"`).join(' | ');
  }
}

// ------------------------------------------------------------- combinators

class OptionalSchema<T> extends Schema<T | undefined> {
  private readonly inner: Schema<T>;

  constructor(inner: Schema<T>) {
    super();
    this.inner = inner;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<T | undefined> {
    if (value === undefined) return { ok: true, value: undefined };
    return this.inner.safeParse(value, path);
  }

  override describe(): string {
    return `${this.inner.describe()}?`;
  }
}

class NullableSchema<T> extends Schema<T | null> {
  private readonly inner: Schema<T>;

  constructor(inner: Schema<T>) {
    super();
    this.inner = inner;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<T | null> {
    if (value === null) return { ok: true, value: null };
    return this.inner.safeParse(value, path);
  }

  override describe(): string {
    return `${this.inner.describe()} | null`;
  }
}

class DefaultSchema<T> extends Schema<T> {
  private readonly inner: Schema<T>;
  private readonly fallback: T;

  constructor(inner: Schema<T>, fallback: T) {
    super();
    this.inner = inner;
    this.fallback = fallback;
  }

  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<T> {
    if (value === undefined) return { ok: true, value: this.fallback };
    return this.inner.safeParse(value, path);
  }

  override describe(): string {
    return `${this.inner.describe()} = ${JSON.stringify(this.fallback)}`;
  }
}

class TransformSchema<In, Out> extends Schema<Out> {
  private readonly inner: Schema<In>;
  private readonly fn: (value: In) => Out;

  constructor(inner: Schema<In>, fn: (value: In) => Out) {
    super();
    this.inner = inner;
    this.fn = fn;
  }

  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<Out> {
    const result = this.inner.safeParse(value, path);
    return result.ok ? { ok: true, value: this.fn(result.value) } : result;
  }

  override describe(): string {
    return `${this.inner.describe()} -> transformed`;
  }
}

class ArraySchema<T> extends Schema<T[]> {
  private readonly element: Schema<T>;

  constructor(element: Schema<T>) {
    super();
    this.element = element;
  }

  protected parseValue(value: unknown, path: ReadonlyArray<string | number>): Result<T[]> {
    if (!Array.isArray(value)) {
      return { ok: false, issues: [typeIssue('an array', value, path)] };
    }

    const out: T[] = [];
    const issues: Issue[] = [];
    value.forEach((item, index) => {
      const result = this.element.safeParse(item, [...path, index]);
      if (result.ok) out.push(result.value);
      else issues.push(...result.issues);
    });

    return issues.length ? { ok: false, issues } : { ok: true, value: out };
  }

  min(length: number): this {
    const next = Object.create(this) as this;
    next.checks = [
      ...this.checks,
      (value, path) =>
        value.length >= length
          ? null
          : { path, message: `must have at least ${length} item(s)`, code: 'too_small' },
    ];
    return next;
  }

  override describe(): string {
    return `${this.element.describe()}[]`;
  }
}

/** The shape a set of field schemas describes. */
type Shape = Record<string, Schema<unknown>>;

/**
 * Mapped and conditional types together: optional fields become optional
 * properties rather than required ones that may be undefined.
 */
type OptionalKeys<S extends Shape> = {
  [K in keyof S]: undefined extends Infer<S[K]> ? K : never;
}[keyof S];

type RequiredKeys<S extends Shape> = Exclude<keyof S, OptionalKeys<S>>;

type ObjectOf<S extends Shape> = {
  [K in RequiredKeys<S>]: Infer<S[K]>;
} & {
  [K in OptionalKeys<S>]?: Infer<S[K]>;
};

/** Flattens an intersection so hover text reads as one object. */
type Pretty<T> = { [K in keyof T]: T[K] } & {};

class ObjectSchema<S extends Shape> extends Schema<Pretty<ObjectOf<S>>> {
  readonly shape: S;
  private readonly mode: 'strip' | 'strict' | 'passthrough';

  constructor(shape: S, mode: 'strip' | 'strict' | 'passthrough' = 'strip') {
    super();
    this.shape = shape;
    this.mode = mode;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<Pretty<ObjectOf<S>>> {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      return { ok: false, issues: [typeIssue('an object', value, path)] };
    }

    const source = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    const issues: Issue[] = [];

    for (const key of Object.keys(this.shape)) {
      const result = this.shape[key]!.safeParse(source[key], [...path, key]);
      if (!result.ok) {
        issues.push(...result.issues);
        continue;
      }
      // An absent optional field stays absent rather than becoming undefined.
      if (result.value !== undefined || key in source) out[key] = result.value;
    }

    const extra = Object.keys(source).filter((key) => !(key in this.shape));
    if (this.mode === 'strict' && extra.length) {
      for (const key of extra) {
        issues.push({
          path: [...path, key],
          message: 'unrecognised key',
          code: 'unrecognised_key',
        });
      }
    } else if (this.mode === 'passthrough') {
      for (const key of extra) out[key] = source[key];
    }

    return issues.length
      ? { ok: false, issues }
      : { ok: true, value: out as Pretty<ObjectOf<S>> };
  }

  strict(): ObjectSchema<S> {
    return new ObjectSchema(this.shape, 'strict');
  }

  passthrough(): ObjectSchema<S> {
    return new ObjectSchema(this.shape, 'passthrough');
  }

  /** A new schema with only the named fields, typed accordingly. */
  pick<K extends keyof S & string>(...keys: K[]): ObjectSchema<Pick<S, K>> {
    const shape = {} as Pick<S, K>;
    for (const key of keys) shape[key] = this.shape[key];
    return new ObjectSchema(shape, this.mode);
  }

  extend<E extends Shape>(extra: E): ObjectSchema<S & E> {
    return new ObjectSchema({ ...this.shape, ...extra }, this.mode);
  }

  override describe(): string {
    const fields = Object.entries(this.shape)
      .map(([key, schema]) => `${key}: ${schema.describe()}`)
      .join('; ');
    return `{ ${fields} }`;
  }
}

/**
 * A tagged union. The discriminant tells the parser which member to try, so a
 * failure reports one useful message rather than every member's complaint.
 */
class UnionSchema<
  K extends string,
  M extends Record<string, ObjectSchema<Shape>>,
> extends Schema<{ [T in keyof M]: Infer<M[T]> }[keyof M]> {
  private readonly discriminant: K;
  private readonly members: M;

  constructor(discriminant: K, members: M) {
    super();
    this.discriminant = discriminant;
    this.members = members;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<{ [T in keyof M]: Infer<M[T]> }[keyof M]> {
    if (typeof value !== 'object' || value === null) {
      return { ok: false, issues: [typeIssue('an object', value, path)] };
    }

    const tag = (value as Record<string, unknown>)[this.discriminant];
    if (typeof tag !== 'string' || !(tag in this.members)) {
      return {
        ok: false,
        issues: [
          {
            path: [...path, this.discriminant],
            message: `must be one of: ${Object.keys(this.members).join(', ')}`,
            code: 'invalid_union',
          },
        ],
      };
    }

    return this.members[tag]!.safeParse(value, path) as Result<
      { [T in keyof M]: Infer<M[T]> }[keyof M]
    >;
  }

  override describe(): string {
    return Object.keys(this.members)
      .map((tag) => `${this.discriminant}="${tag}"`)
      .join(' | ');
  }
}

class RecordSchema<T> extends Schema<Record<string, T>> {
  private readonly valueSchema: Schema<T>;

  constructor(valueSchema: Schema<T>) {
    super();
    this.valueSchema = valueSchema;
  }

  protected parseValue(
    value: unknown,
    path: ReadonlyArray<string | number>,
  ): Result<Record<string, T>> {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      return { ok: false, issues: [typeIssue('an object', value, path)] };
    }

    const out: Record<string, T> = {};
    const issues: Issue[] = [];
    for (const [key, item] of Object.entries(value)) {
      const result = this.valueSchema.safeParse(item, [...path, key]);
      if (result.ok) out[key] = result.value;
      else issues.push(...result.issues);
    }
    return issues.length ? { ok: false, issues } : { ok: true, value: out };
  }

  override describe(): string {
    return `Record<string, ${this.valueSchema.describe()}>`;
  }
}

// ------------------------------------------------------------- constructors

export const string = (): StringSchema => new StringSchema();
export const number = (): NumberSchema => new NumberSchema();
export const boolean = (): BooleanSchema => new BooleanSchema();
export const literal = <const T extends ReadonlyArray<string>>(...values: T) =>
  new LiteralSchema(values);
export const array = <T>(element: Schema<T>): ArraySchema<T> => new ArraySchema(element);
export const object = <S extends Shape>(shape: S): ObjectSchema<S> =>
  new ObjectSchema(shape);
export const record = <T>(valueSchema: Schema<T>): RecordSchema<T> =>
  new RecordSchema(valueSchema);
export const union = <K extends string, M extends Record<string, ObjectSchema<Shape>>>(
  discriminant: K,
  members: M,
) => new UnionSchema(discriminant, members);

// ------------------------------------------------------------- demonstration

const Sailing = object({
  id: string().min(3).matches(/^[A-Z]{3}-\d+$/, 'must look like HRB-12'),
  departs: string().matches(/^\d{2}:\d{2}$/, 'must be HH:MM'),
  vessel: literal('MV Kestrel', 'MV Halloway', 'MV Marlow', 'MV Fenwick'),
  seats: number().int().min(1).max(400),
  load: number().min(0).max(100).withDefault(50),
  notes: string().max(120).optional(),
});

const Route = object({
  code: string().matches(/^[A-Z]{3}$/, 'must be three capitals'),
  name: string().min(1),
  active: boolean(),
  opened: string().isoDate(),
  sailings: array(Sailing).min(1),
});

// These types are inferred from the schemas above; nothing declares them.
type Sailing = Infer<typeof Sailing>;
type Route = Infer<typeof Route>;

const Event = union('kind', {
  cancelled: object({
    kind: literal('cancelled'),
    sailingId: string(),
    reason: literal('weather', 'mechanical', 'crew', 'berth'),
  }),
  delayed: object({
    kind: literal('delayed'),
    sailingId: string(),
    minutes: number().int().min(1),
  }),
  diverted: object({
    kind: literal('diverted'),
    sailingId: string(),
    to: string().min(1),
  }),
});

type Event = Infer<typeof Event>;

function report(title: string, result: Result<unknown>): void {
  console.log(`\n${title}`);
  if (result.ok) {
    console.log('  ok:', JSON.stringify(result.value));
  } else {
    for (const issue of result.issues) {
      console.log(`  ${formatPath(issue.path).padEnd(28)} ${issue.message}  [${issue.code}]`);
    }
  }
}

function demonstrate(): void {
  console.log('--- the schema, described ---');
  console.log('  Sailing', Sailing.describe());
  console.log('  Event  ', Event.describe());

  const goodRoute: unknown = {
    code: 'HRB',
    name: 'Harbour Loop',
    active: true,
    opened: '2021-06-14',
    sailings: [
      { id: 'HRB-1', departs: '06:20', vessel: 'MV Marlow', seats: 380, load: 78 },
      { id: 'HRB-2', departs: '06:40', vessel: 'MV Marlow', seats: 380, notes: 'peak' },
    ],
  };
  report('--- a valid route ---', Route.safeParse(goodRoute));

  const parsed: Route = Route.parse(goodRoute);
  console.log('\n--- the inferred type is real ---');
  console.log(`  ${parsed.name} has ${parsed.sailings.length} sailing(s)`);
  console.log(`  the second sailing defaulted its load to ${parsed.sailings[1]!.load}`);
  console.log(`  the first sailing has no notes: ${!('notes' in parsed.sailings[0]!)}`);

  const badRoute: unknown = {
    code: 'harbour',
    name: '',
    active: 'yes',
    opened: '14/06/2021',
    sailings: [
      { id: 'x', departs: '6:20', vessel: 'MV Nonexistent', seats: 0 },
      { id: 'HRB-2', departs: '06:40', vessel: 'MV Marlow', seats: 1200, load: 150 },
    ],
  };
  report('--- an invalid route, every problem at once ---', Route.safeParse(badRoute));

  console.log('\n--- unknown keys ---');
  const withExtra = { code: 'KSP', name: 'Kestrel Point', active: true,
                      opened: '2024-01-08', sailings: [
                        { id: 'KSP-1', departs: '07:00', vessel: 'MV Kestrel', seats: 240 },
                      ], colour: 'blue', legacyId: 44 };
  const stripped = Route.safeParse(withExtra);
  console.log('  strip mode kept:',
    stripped.ok ? Object.keys(stripped.value as object).join(', ') : 'failed');
  report('  strict mode', Route.strict().safeParse(withExtra));

  console.log('\n--- a discriminated union ---');
  const events: unknown[] = [
    { kind: 'cancelled', sailingId: 'HRB-3', reason: 'weather' },
    { kind: 'delayed', sailingId: 'KSP-2', minutes: 25 },
    { kind: 'diverted', sailingId: 'HLW-1', to: 'North Landing' },
    { kind: 'delayed', sailingId: 'KSP-3', minutes: 0 },
    { kind: 'exploded', sailingId: 'NCR-1' },
  ];
  for (const candidate of events) {
    const result = Event.safeParse(candidate);
    if (isOk(result)) {
      // The narrowed union means every branch below is checked.
      const event = result.value as Event;
      const summary =
        event.kind === 'cancelled'
          ? `cancelled (${event.reason})`
          : event.kind === 'delayed'
            ? `delayed ${event.minutes} min`
            : `diverted to ${event.to}`;
      console.log(`  ${event.sailingId.padEnd(8)} ${summary}`);
    } else {
      console.log(`  rejected: ${result.issues.map((i) => i.message).join('; ')}`);
    }
  }

  console.log('\n--- pick and extend ---');
  const Summary = Sailing.pick('id', 'departs', 'vessel');
  console.log('  picked:', Summary.describe());
  const Extended = Summary.extend({ platform: number().int().min(1) });
  console.log('  extended:', Extended.describe());
  report('  parsed against the extended schema',
    Extended.safeParse({ id: 'HRB-9', departs: '07:00', vessel: 'MV Marlow', platform: 2 }));

  console.log('\n--- transform and refine ---');
  const Minutes = string()
    .matches(/^\d{2}:\d{2}$/, 'must be HH:MM')
    .transform((text) => {
      const [hour, minute] = text.split(':').map(Number) as [number, number];
      return hour * 60 + minute;
    })
    .refine((value) => value < 1440, 'must be a real time of day');
  report('  "07:45" as minutes', Minutes.safeParse('07:45'));
  report('  "99:99" as minutes', Minutes.safeParse('99:99'));

  console.log('\n--- a record of counts ---');
  const Counts = record(number().int().min(0));
  report('  valid', Counts.safeParse({ HRB: 83755, KSP: 63325 }));
  report('  invalid', Counts.safeParse({ HRB: 83755, KSP: -1, HLW: 'many' }));

  console.log('\n--- parse throws where safeParse reports ---');
  try {
    Route.parse({ code: 'nope' });
  } catch (error) {
    if (error instanceof ValidationError) {
      console.log(`  ${error.name}: ${error.issues.length} issue(s)`);
      console.log(`  first: ${error.issues[0]!.message}`);
    }
  }
}

demonstrate();
