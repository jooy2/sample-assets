// A Result type: making failure part of the return value rather than an
// exception the caller may forget to handle.

type Ok<T> = { readonly ok: true; readonly value: T };
type Err<E> = { readonly ok: false; readonly error: E };
export type Result<T, E = Error> = Ok<T> | Err<E>;

const ok = <T>(value: T): Ok<T> => ({ ok: true, value });
const err = <E>(error: E): Err<E> => ({ ok: false, error });

// The combinators. Each one leaves a failure untouched.
function map<T, U, E>(result: Result<T, E>, fn: (value: T) => U): Result<U, E> {
  return result.ok ? ok(fn(result.value)) : result;
}

function mapError<T, E, F>(result: Result<T, E>, fn: (error: E) => F): Result<T, F> {
  return result.ok ? result : err(fn(result.error));
}

function andThen<T, U, E>(result: Result<T, E>, fn: (value: T) => Result<U, E>): Result<U, E> {
  return result.ok ? fn(result.value) : result;
}

function unwrapOr<T, E>(result: Result<T, E>, fallback: T): T {
  return result.ok ? result.value : fallback;
}

/** Stops at the first failure, the way Rust's collect() does. */
function all<T, E>(results: readonly Result<T, E>[]): Result<T[], E> {
  const values: T[] = [];
  for (const result of results) {
    if (!result.ok) return result;
    values.push(result.value);
  }
  return ok(values);
}

/** Keeps both sides, for when every failure matters. */
function partition<T, E>(results: readonly Result<T, E>[]): { values: T[]; errors: E[] } {
  const values: T[] = [];
  const errors: E[] = [];
  for (const result of results) {
    result.ok ? values.push(result.value) : errors.push(result.error);
  }
  return { values, errors };
}

/** Wraps a throwing function, which is how this meets the rest of the world. */
function attempt<T>(fn: () => T): Result<T, Error> {
  try {
    return ok(fn());
  } catch (error) {
    return err(error instanceof Error ? error : new Error(String(error)));
  }
}

// --- using it --------------------------------------------------------------

type LoadError =
  | { kind: "not-found"; key: string }
  | { kind: "not-a-number"; raw: string }
  | { kind: "out-of-range"; value: number };

const CONFIGURATION: Record<string, string> = {
  port: "8080",
  zone: "3",
  timeout: "soon",
  retries: "900",
};

function read(key: string): Result<string, LoadError> {
  const raw = CONFIGURATION[key];
  return raw === undefined ? err({ kind: "not-found", key }) : ok(raw);
}

function parseZone(raw: string): Result<number, LoadError> {
  const value = Number(raw);
  if (!Number.isInteger(value)) return err({ kind: "not-a-number", raw });
  if (value < 1 || value > 6) return err({ kind: "out-of-range", value });
  return ok(value);
}

const zoneFor = (key: string): Result<number, LoadError> => andThen(read(key), parseZone);

function explain(error: LoadError): string {
  switch (error.kind) {
    case "not-found":
      return `${error.key} is missing`;
    case "not-a-number":
      return `"${error.raw}" is not a number`;
    case "out-of-range":
      return `${error.value} is outside 1-6`;
  }
}

for (const key of ["zone", "timeout", "retries", "missing"]) {
  const result = zoneFor(key);
  console.log(
    key.padEnd(9),
    result.ok ? `-> zone ${result.value}` : `!  ${explain(result.error)}`,
  );
}

console.log("mapped:", map(zoneFor("zone"), (zone) => zone * 10));
console.log("mapped error:", mapError(zoneFor("missing"), explain));
console.log("fallback:", unwrapOr(zoneFor("missing"), 1));

console.log("all good:", all(["1", "2", "3"].map(parseZone)));
console.log("one bad:", all(["1", "nine", "3"].map(parseZone)));

const { values, errors } = partition(["1", "nine", "4", "12"].map(parseZone));
console.log("kept", values, "| rejected", errors.map(explain));

console.log("wrapped a throw:", attempt(() => JSON.parse("{ broken") as unknown).ok);
console.log("wrapped a success:", attempt(() => JSON.parse('{"zone":2}') as { zone: number }));
