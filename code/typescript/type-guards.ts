// Type guards: teaching the compiler what a runtime check proves.

interface Station {
  kind: "station";
  name: string;
  zone: number;
}

interface Depot {
  kind: "depot";
  name: string;
  capacity: number;
}

type Site = Station | Depot;

// A user-defined type guard: the `value is T` return type is the point.
function isStation(site: Site): site is Station {
  return site.kind === "station";
}

// A guard over unknown, which is where parsing input starts.
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isStationPayload(value: unknown): value is { name: string; zone: number } {
  return (
    isRecord(value) &&
    typeof value.name === "string" &&
    typeof value.zone === "number" &&
    Number.isInteger(value.zone)
  );
}

// An assertion function narrows for the rest of the scope, and throws
// otherwise. The explicit return type annotation is required.
function assertIsStation(site: Site): asserts site is Station {
  if (site.kind !== "station") {
    throw new Error(`expected a station, got a ${site.kind}`);
  }
}

// A guard for filtering out null and undefined.
function isPresent<T>(value: T | null | undefined): value is T {
  return value !== null && value !== undefined;
}

const sites: Site[] = [
  { kind: "station", name: "Alder Cross", zone: 2 },
  { kind: "depot", name: "Northgate Depot", capacity: 40 },
  { kind: "station", name: "Quill Wharf", zone: 3 },
];

for (const site of sites) {
  if (isStation(site)) {
    console.log(`${site.name} is in zone ${site.zone}`);
  } else {
    console.log(`${site.name} holds ${site.capacity} vehicles`);
  }
}

// A guard composes with filter, and narrows the resulting array's type.
const stations = sites.filter(isStation);
console.log("stations only:", stations.map((s) => s.zone));

const maybe: (string | null | undefined)[] = ["Amber", null, "Cobalt", undefined];
console.log("present:", maybe.filter(isPresent));

// Parsing untrusted input.
for (const payload of ['{"name":"Nether Gate","zone":2}', '{"name":"broken"}']) {
  const parsed: unknown = JSON.parse(payload);
  if (isStationPayload(parsed)) {
    console.log("accepted", parsed.name, "zone", parsed.zone);
  } else {
    console.log("rejected", payload);
  }
}

try {
  const site: Site = sites[1]; // a Depot, but the compiler only knows it is a Site
  assertIsStation(site);
  console.log(site.zone); // narrowed past the assertion
} catch (error) {
  console.log("assertion failed:", (error as Error).message);
}

// The built-in narrowing operators, for reference.
const values: unknown[] = ["amber", 42, true, null, [1, 2], new Date(), () => 1];
for (const value of values) {
  const description =
    typeof value === "string"
      ? "string"
      : typeof value === "number"
        ? "number"
        : typeof value === "boolean"
          ? "boolean"
          : typeof value === "function"
            ? "function"
            : value === null
              ? "null"
              : Array.isArray(value)
                ? "array"
                : value instanceof Date
                  ? "Date"
                  : "object";
  console.log(" ", description);
}
