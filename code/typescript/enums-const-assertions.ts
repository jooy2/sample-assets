// enum, const enum, and the `as const` object that usually replaces both.

// A numeric enum: the members get 0, 1, 2... unless told otherwise.
enum Priority {
  Low,
  Normal,
  High,
  Urgent,
}

// A string enum: every member needs its own value, and there is no reverse
// mapping.
enum TransitLine {
  Amber = "amber",
  Cobalt = "cobalt",
  Emerald = "emerald",
  Crimson = "crimson",
}

enum HttpStatus {
  Ok = 200,
  Created = 201,
  NotFound = 404,
  ServerError = 500,
}

console.log(Priority.High, "|", Priority[2]); // numeric enums map both ways
console.log(TransitLine.Cobalt, "|", Object.values(TransitLine));
console.log("status:", HttpStatus.NotFound, HttpStatus[404]);

function responseTime(priority: Priority): string {
  switch (priority) {
    case Priority.Low:
      return "within a week";
    case Priority.Normal:
      return "within two days";
    case Priority.High:
      return "within four hours";
    case Priority.Urgent:
      return "immediately";
  }
}
console.log(responseTime(Priority.Urgent));

// `as const` freezes an object's inferred types to their literals, which
// gives the same safety with a plain object and no runtime enum.
const ZONES = {
  central: 1,
  inner: 2,
  suburban: 3,
  outer: 5,
} as const;

type ZoneName = keyof typeof ZONES;
type ZoneValue = (typeof ZONES)[ZoneName];

const zoneName: ZoneName = "suburban";
const zoneValue: ZoneValue = ZONES[zoneName];
console.log(`${zoneName} is zone ${zoneValue}`);
console.log("names:", Object.keys(ZONES));

// The same trick for a list of allowed strings.
const LINES = ["Amber", "Cobalt", "Emerald", "Crimson", "Slate"] as const;
type Line = (typeof LINES)[number];

function isLine(value: string): value is Line {
  return (LINES as readonly string[]).includes(value);
}
console.log("Cobalt is a line:", isLine("Cobalt"), "| Violet:", isLine("Violet"));

// as const also makes arrays readonly tuples, which stops accidental writes.
const point = [45, -10] as const;
console.log("tuple:", point[0], point[1]);
// point[0] = 0;   // error: cannot assign to '0' because it is read-only

// A literal type is widened without `as const`, and kept with it.
const widened = { line: "Amber" };
const narrowed = { line: "Amber" } as const;
type Widened = typeof widened.line; // string
type Narrowed = typeof narrowed.line; // "Amber"
const w: Widened = "anything";
const n: Narrowed = "Amber";
console.log({ w, n });

// A satisfies clause checks the shape without widening the literals.
const fares = {
  Amber: 2.4,
  Cobalt: 2.6,
} satisfies Partial<Record<Line, number>>;
console.log("fare keys stay literal:", Object.keys(fares), fares.Amber);
