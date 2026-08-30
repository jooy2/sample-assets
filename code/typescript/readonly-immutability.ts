// readonly, Readonly<T>, and as const are compile-time only. Object.freeze
// is the runtime half.

interface Station {
  readonly id: string;
  name: string;
  readonly platforms: readonly number[];
}

const alder: Station = {
  id: "ST-001",
  name: "Alder Cross",
  platforms: [1, 2],
};

// alder.id = "ST-999";        // error: cannot assign to a read-only property
// alder.platforms.push(3);    // error: push does not exist on a readonly array
alder.name = "Alder Cross Station"; // allowed: not readonly
console.log(alder.name, alder.platforms);

// Readonly<T> makes every property readonly, one level deep.
type FrozenStation = Readonly<Station>;
const frozen: FrozenStation = { ...alder };
console.log("shallow:", frozen.name);

// ReadonlyArray and ReadonlyMap block the mutating methods.
const lines: ReadonlyArray<string> = ["Amber", "Cobalt", "Emerald"];
const zones: ReadonlyMap<string, number> = new Map([["Alder Cross", 2]]);
const accessible: ReadonlySet<string> = new Set(["Amber"]);

console.log(lines.length, [...lines].reverse(), zones.get("Alder Cross"), accessible.has("Amber"));
// lines.push("Crimson");   // error: push does not exist on a readonly array

// The non-mutating array methods return a new array, so they still work.
console.log("toSorted:", lines.toSorted());
console.log("with:", lines.with(0, "Crimson"));
console.log("concat:", lines.concat("Slate"));

// as const gives the deepest compile-time immutability, and literal types.
const NETWORK = {
  operator: "Veranix Transit",
  lines: ["Amber", "Cobalt"],
  fares: { base: 2.4, perZone: 0.85 },
} as const;

type Operator = typeof NETWORK.operator; // "Veranix Transit", not string
const operator: Operator = "Veranix Transit";
console.log(operator, NETWORK.fares.base);
// NETWORK.fares.base = 3;   // error, and so is every level below it

// None of the above changes anything at runtime.
const mutableAtRuntime: Readonly<{ zone: number }> = { zone: 2 };
(mutableAtRuntime as { zone: number }).zone = 3;
console.log("readonly is erased at runtime:", mutableAtRuntime.zone);

// Object.freeze is the runtime guard, and is also shallow.
const reallyFrozen = Object.freeze({ zone: 2, nested: { platforms: 2 } });
try {
  (reallyFrozen as { zone: number }).zone = 3;
} catch {
  console.log("in strict mode, assigning to a frozen property throws");
}
reallyFrozen.nested.platforms = 4;
console.log("frozen:", Object.isFrozen(reallyFrozen), "| nested still mutable:", reallyFrozen.nested.platforms);

// A deep freeze has to walk the structure itself.
function deepFreeze<T>(value: T): Readonly<T> {
  if (value && typeof value === "object") {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}
const deep = deepFreeze({ zone: 2, nested: { platforms: 2 } });
console.log("deep frozen:", Object.isFrozen(deep.nested));

// Updating immutably: build a new value rather than changing one.
const updated: Station = { ...alder, name: "Alder Cross Interchange" };
const withPlatform: Station = { ...alder, platforms: [...alder.platforms, 3] };
console.log(updated.name, "|", withPlatform.platforms, "| original", alder.platforms);
