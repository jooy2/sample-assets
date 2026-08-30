// interface and type alias: what each can do, and when the difference
// actually matters.

interface Station {
  readonly id: string;
  name: string;
  zone: number;
  nickname?: string; // optional
  [key: string]: unknown; // index signature: any other key is allowed
}

// An interface can be reopened, which a type alias cannot.
interface Station {
  line: string;
}

// Interfaces extend; type aliases intersect.
interface Timestamped {
  createdAt: string;
  updatedAt: string;
}

interface AuditedStation extends Station, Timestamped {
  auditedBy: string;
}

// A type alias can name anything, not only an object shape.
type Zone = 1 | 2 | 3 | 4 | 5 | 6;
type StationId = `ST-${number}`;
type Coordinates = readonly [x: number, y: number];
type Predicate<T> = (value: T) => boolean;
type Nullable<T> = T | null;

type Fare = {
  base: number;
  perZone: number;
};

type OffPeakFare = Fare & { discount: number };

// A call signature and a construct signature, in both styles.
interface FareCalculator {
  (zones: number): number;
  currency: string;
}

const alder: AuditedStation = {
  id: "ST-001",
  name: "Alder Cross",
  line: "Amber",
  zone: 2,
  nickname: "the Cross",
  createdAt: "2025-01-04T09:00:00Z",
  updatedAt: "2025-11-03T09:15:00Z",
  auditedBy: "imogen.hawthorne",
  platforms: 2, // allowed by the index signature
};

const fare: OffPeakFare = { base: 2.4, perZone: 0.85, discount: 0.2 };

const calculate: FareCalculator = Object.assign(
  (zones: number) => fare.base + zones * fare.perZone,
  { currency: "USD" },
);

const isDeep: Predicate<Station> = (station) => station.zone > 4;

console.log(alder.name, "in zone", alder.zone, "on", alder.line);
console.log("audited by", alder.auditedBy, "at", alder.updatedAt);
console.log("index signature:", alder.platforms);
console.log("fare:", calculate(3).toFixed(2), calculate.currency);
console.log("deep:", isDeep(alder));

const zone: Zone = 3;
const id: StationId = "ST-001";
const point: Coordinates = [45, -10];
const maybe: Nullable<string> = null;
console.log({ zone, id, point, maybe });

// readonly is checked at compile time only; nothing is frozen at runtime.
// alder.id = "ST-999";   // error: cannot assign to a read-only property
console.log("id stays", alder.id);
