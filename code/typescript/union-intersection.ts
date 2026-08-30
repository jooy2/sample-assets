// Unions are "one of"; intersections are "all of". Narrowing is how you get
// from a union back to one member.

type Line = "Amber" | "Cobalt" | "Emerald" | "Crimson" | "Slate";
type Zone = 1 | 2 | 3 | 4 | 5 | 6;
type Id = string | number;

interface Timestamped {
  createdAt: string;
}

interface Named {
  name: string;
}

interface Located {
  gridX: number;
  gridY: number;
}

// An intersection combines every member's properties.
type Station = Named & Located & Timestamped & { line: Line; zone: Zone };

const alder: Station = {
  name: "Alder Cross",
  gridX: 45,
  gridY: -10,
  createdAt: "2025-01-04T09:00:00Z",
  line: "Amber",
  zone: 2,
};

console.log(alder.name, alder.line, `${alder.gridX},${alder.gridY}`);

// Only the members every branch of a union has are reachable without a check.
function describe(value: Id): string {
  if (typeof value === "string") {
    return `a string of ${value.length} characters`; // narrowed to string
  }
  return `the number ${value.toFixed(0)}`; // narrowed to number
}
console.log(describe("ST-001"), "|", describe(42));

// Narrowing with in, instanceof, truthiness, and equality.
type Success = { status: "ok"; value: number };
type Failure = { status: "error"; message: string };
type Outcome = Success | Failure;

function report(outcome: Outcome): string {
  if ("value" in outcome) {
    return `ok: ${outcome.value}`;
  }
  return `error: ${outcome.message}`;
}
console.log(report({ status: "ok", value: 3 }));
console.log(report({ status: "error", message: "out of range" }));

function lengthOf(value: string | string[] | null): number {
  if (value === null) return 0;
  if (Array.isArray(value)) return value.length;
  return value.length;
}
console.log([lengthOf(null), lengthOf("amber"), lengthOf(["a", "b"])]);

// A literal union is checked at compile time, which catches typos.
function platformsFor(line: Line): number {
  switch (line) {
    case "Amber":
    case "Cobalt":
      return 4;
    case "Emerald":
    case "Crimson":
      return 3;
    case "Slate":
      return 2;
  }
}
console.log("Amber:", platformsFor("Amber"), "| Slate:", platformsFor("Slate"));

// Unions distribute over generics and over template literal types.
type Prefixed<T extends string> = `line-${T}`;
const slug: Prefixed<Line> = "line-Cobalt";
console.log("template literal type:", slug);

// A union of function types can only be called with the arguments they
// all accept, so an overload or a generic is usually better.
type Transform = ((value: string) => string) | ((value: number) => number);
const transforms: Transform[] = [(s: string) => s.toUpperCase(), (n: number) => n * 2];
console.log("stored, called after narrowing:", (transforms[0] as (v: string) => string)("amber"));

// never is the empty union: nothing has that type.
function unreachable(value: never): never {
  throw new Error(`unexpected value: ${JSON.stringify(value)}`);
}
function fareBand(zone: 1 | 2): string {
  if (zone === 1) return "inner";
  if (zone === 2) return "central";
  return unreachable(zone);
}
console.log(fareBand(1), fareBand(2));
