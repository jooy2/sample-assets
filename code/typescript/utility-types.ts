// The utility types that ship with TypeScript, and what each one is for.

interface Station {
  id: string;
  name: string;
  line: string;
  zone: number;
  platforms: number;
  stepFree: boolean;
  nickname?: string;
}

// Partial: every property optional. The usual shape of an update payload.
type StationUpdate = Partial<Station>;

// Required: the opposite, including the ones that were optional.
type CompleteStation = Required<Station>;

// Readonly: no assignment after construction.
type FrozenStation = Readonly<Station>;

// Pick and Omit choose or drop properties by name.
type StationSummary = Pick<Station, "id" | "name" | "zone">;
type StationWithoutId = Omit<Station, "id">;

// Record builds an object type from a key union and a value type.
type PlatformsByLine = Record<"Amber" | "Cobalt" | "Emerald", number>;

// Exclude and Extract filter a union.
type Line = "Amber" | "Cobalt" | "Emerald" | "Crimson" | "Slate";
type AccessibleLine = Exclude<Line, "Emerald" | "Slate">;
type WarmLine = Extract<Line, "Amber" | "Crimson">;

// NonNullable drops null and undefined.
type DefinitelyString = NonNullable<string | null | undefined>;

// ReturnType, Parameters, and Awaited read a function's own types.
function makeStation(name: string, zone: number) {
  return { id: `ST-${zone}`, name, zone, stepFree: false };
}
type MadeStation = ReturnType<typeof makeStation>;
type MakeArgs = Parameters<typeof makeStation>;

async function loadStation(): Promise<Station> {
  return { id: "ST-001", name: "Alder Cross", line: "Amber", zone: 2, platforms: 2, stepFree: true };
}
type Loaded = Awaited<ReturnType<typeof loadStation>>;

const alder: Station = {
  id: "ST-001",
  name: "Alder Cross",
  line: "Amber",
  zone: 2,
  platforms: 2,
  stepFree: true,
};

function applyUpdate(station: Station, update: StationUpdate): Station {
  return { ...station, ...update };
}
console.log(applyUpdate(alder, { zone: 3, nickname: "the Cross" }));

const summary: StationSummary = { id: alder.id, name: alder.name, zone: alder.zone };
console.log("summary:", summary);

const { id: _discardedId, ...rest } = alder;
const withoutId: StationWithoutId = rest;
console.log("keys without id:", Object.keys(withoutId));

const platforms: PlatformsByLine = { Amber: 4, Cobalt: 4, Emerald: 3 };
console.log("platforms:", platforms);

const accessible: AccessibleLine = "Crimson";
const warm: WarmLine = "Amber";
const definitely: DefinitelyString = "never null";
console.log({ accessible, warm, definitely });

const args: MakeArgs = ["Quill Wharf", 3];
const made: MadeStation = makeStation(...args);
console.log("made:", made);

void loadStation().then((loaded: Loaded) => console.log("awaited:", loaded.name));

// Readonly is compile-time only; Object.freeze is the runtime version.
const frozen: FrozenStation = Object.freeze({ ...alder });
console.log("frozen at runtime:", Object.isFrozen(frozen));

// A Required type still needs every key at the value level.
const complete: CompleteStation = { ...alder, nickname: "the Cross" };
console.log("complete:", complete.nickname);

// Uppercase, Lowercase, Capitalize, and Uncapitalize work on string types.
type Shouted = Uppercase<Line>;
const shouted: Shouted = "AMBER";
console.log("shouted:", shouted);
