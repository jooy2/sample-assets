// Mapped types build one object type from another; conditional types choose
// between two, and `infer` pulls a type out of a position.

interface Station {
  id: string;
  name: string;
  zone: number;
  stepFree: boolean;
  openedOn: Date;
}

// A mapped type walks the keys of another type.
type Optional<T> = { [K in keyof T]?: T[K] };
type Immutable<T> = { readonly [K in keyof T]: T[K] };

// The + and - modifiers add or remove readonly and optional.
type Mutable<T> = { -readonly [K in keyof T]: T[K] };
type Concrete<T> = { [K in keyof T]-?: T[K] };

// `as` remaps the key itself, which is how getters get generated.
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

// Filtering keys by their value type: the never branch drops the key.
type KeysOfType<T, V> = { [K in keyof T]: T[K] extends V ? K : never }[keyof T];
type StringKeys = KeysOfType<Station, string>;

// A conditional type, and the distributive behaviour over a union.
type ArrayOf<T> = T extends unknown[] ? T : T[];
type Flatten<T> = T extends readonly (infer Item)[] ? Item : T;

// infer reads a type out of a function, a promise, or a tuple.
type FirstArgument<F> = F extends (first: infer A, ...rest: never[]) => unknown ? A : never;
type Unwrap<T> = T extends Promise<infer Inner> ? Unwrap<Inner> : T;
type Head<T extends readonly unknown[]> = T extends readonly [infer First, ...unknown[]] ? First : never;

// A recursive mapped type reaches all the way down.
type DeepReadonly<T> = T extends (infer Item)[]
  ? readonly DeepReadonly<Item>[]
  : T extends object
    ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
    : T;

const partial: Optional<Station> = { name: "Alder Cross" };
const frozen: Immutable<Station> = {
  id: "ST-001",
  name: "Alder Cross",
  zone: 2,
  stepFree: true,
  openedOn: new Date("1978-04-11"),
};
const thawed: Mutable<typeof frozen> = { ...frozen };
thawed.zone = 3;

console.log("partial:", partial);
console.log("mutable copy:", thawed.zone, "| original still", frozen.zone);

const accessors: Getters<Pick<Station, "id" | "zone">> = {
  getId: () => frozen.id,
  getZone: () => frozen.zone,
};
console.log("generated getters:", accessors.getId(), accessors.getZone());

const stringKeys: StringKeys[] = ["id", "name"];
console.log("string-valued keys:", stringKeys);

type A = ArrayOf<string>; // string[]
type B = ArrayOf<number[]>; // number[]
const a: A = ["one"];
const b: B = [1, 2];
console.log({ a, b });

type StationItem = Flatten<readonly Station[]>; // Station
type FirstArg = FirstArgument<(id: string, ms: number) => void>; // string
type Inner = Unwrap<Promise<Promise<number>>>; // number
type FirstOfTuple = Head<[Date, string, number]>; // Date

const element: StationItem = frozen;
const firstArg: FirstArg = "ST-001";
const inner: Inner = 42;
const head: FirstOfTuple = new Date("2025-11-03");
console.log(element.name, firstArg, inner, head.getUTCFullYear());

interface Network {
  name: string;
  lines: { name: string; stations: string[] }[];
}
const network: DeepReadonly<Network> = {
  name: "Veranix Transit",
  lines: [{ name: "Amber", stations: ["Alder Cross"] }],
};
console.log("deep readonly:", network.lines[0]?.stations[0]);
// network.lines[0].name = "x";   // error, all the way down

// Distribution: a conditional type over a union applies to each member.
type ToArray<T> = T extends unknown ? T[] : never;
type Distributed = ToArray<string | number>; // string[] | number[]
const distributed: Distributed = [1, 2];
console.log("distributed:", distributed);
