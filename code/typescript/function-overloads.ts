// Overload signatures describe several ways to call one function; the
// implementation signature is not callable from outside.

interface Station {
  id: string;
  name: string;
  zone: number;
}

const NETWORK: Station[] = [
  { id: "ST-001", name: "Alder Cross", zone: 2 },
  { id: "ST-002", name: "Quill Wharf", zone: 3 },
  { id: "ST-003", name: "Saltwick Halt", zone: 5 },
];

// The overloads a caller sees.
function find(id: string): Station | undefined;
function find(zone: number): Station[];
function find(predicate: (station: Station) => boolean): Station[];
// The implementation: wide enough to cover them all, and invisible outside.
function find(
  query: string | number | ((station: Station) => boolean),
): Station | Station[] | undefined {
  if (typeof query === "string") {
    return NETWORK.find((station) => station.id === query);
  }
  if (typeof query === "number") {
    return NETWORK.filter((station) => station.zone === query);
  }
  return NETWORK.filter(query);
}

const one = find("ST-002");
const byZone = find(2);
const byPredicate = find((station) => station.name.startsWith("S"));

console.log("by id:", one?.name);
console.log("by zone:", byZone.map((s) => s.name));
console.log("by predicate:", byPredicate.map((s) => s.name));

// Overloads on a method, and on a constructor.
class Fare {
  static from(cents: number): Fare;
  static from(amount: string): Fare;
  static from(value: number | string): Fare {
    return new Fare(typeof value === "number" ? value : Math.round(parseFloat(value) * 100));
  }

  private constructor(readonly cents: number) {}

  toString(): string {
    return (this.cents / 100).toFixed(2);
  }
}
console.log("from cents:", Fare.from(240).toString(), "| from a string:", Fare.from("2.40").toString());

// A union parameter often reads better than an overload, when the return
// type does not depend on which one was passed.
function label(value: string | number): string {
  return typeof value === "string" ? value : `#${value}`;
}
console.log(label("Amber"), label(2));

// A generic is better still when the return type follows the argument.
function wrap<T>(value: T): { value: T } {
  return { value };
}
console.log(wrap("Amber").value.toUpperCase(), wrap(2).value.toFixed(1));

// Overloads are ordered: the first match wins, so put the specific ones first.
function format(value: Date): string;
function format(value: number, digits?: number): string;
function format(value: unknown, digits = 2): string {
  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }
  return (value as number).toFixed(digits);
}
console.log(format(new Date("2025-11-03")), "|", format(3.14159), "|", format(3.14159, 4));

// A function type can carry overloads too, written as a call signature list.
type Lookup = {
  (id: string): Station | undefined;
  (zone: number): Station[];
};
const lookup: Lookup = find;
console.log("through the type:", lookup("ST-003")?.name, lookup(5).length);
