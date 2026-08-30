// ES modules: named exports, a default, re-exports, and type-only imports.
// Namespaces are the older alternative, kept here for contrast.

// --- named exports ---------------------------------------------------------

export interface Station {
  readonly id: string;
  name: string;
  zone: number;
}

export type Line = "Amber" | "Cobalt" | "Emerald";

export const MAX_ZONE = 6;

export function makeStation(id: string, name: string, zone: number): Station {
  if (zone < 1 || zone > MAX_ZONE) {
    throw new RangeError(`zone ${zone} is outside 1-${MAX_ZONE}`);
  }
  return { id, name, zone };
}

export class Network {
  readonly #stations: Station[] = [];

  constructor(readonly name: Line) {}

  add(station: Station): this {
    this.#stations.push(station);
    return this;
  }

  get size(): number {
    return this.#stations.length;
  }

  deepestZone(): number {
    return this.#stations.reduce((deepest, station) => Math.max(deepest, station.zone), 0);
  }
}

// A default export: one per module, and named at the import site.
export default function describe(station: Station): string {
  return `${station.name} (zone ${station.zone})`;
}

// Exporting a local under another name.
const OPERATOR = "Veranix Transit";
export { OPERATOR as operator };

// In another file, these would be the import forms:
//
//   import describe, { makeStation, Network, MAX_ZONE } from "./modules-namespaces.js";
//   import type { Station, Line } from "./modules-namespaces.js";
//   import * as transit from "./modules-namespaces.js";
//   export { makeStation } from "./modules-namespaces.js";     // re-export
//   export type { Station } from "./modules-namespaces.js";    // type-only
//
// `import type` is erased entirely, so it can never cause a runtime import.

// --- namespaces ------------------------------------------------------------

// A namespace groups declarations without a file boundary. Modules are the
// modern choice; namespaces still turn up in global type declarations.
export namespace Geometry {
  export interface Point {
    x: number;
    y: number;
  }

  export function distance(a: Point, b: Point): number {
    return Math.hypot(b.x - a.x, b.y - a.y);
  }

  // Not exported from the namespace, so it is private to it.
  const ORIGIN: Point = { x: 0, y: 0 };

  export function fromOrigin(point: Point): number {
    return distance(ORIGIN, point);
  }
}

// --- using them ------------------------------------------------------------

const amber = new Network("Amber")
  .add(makeStation("ST-001", "Alder Cross", 2))
  .add(makeStation("ST-002", "Quill Wharf", 3));

console.log(`${amber.name}: ${amber.size} stations, deepest zone ${amber.deepestZone()}`);
console.log(describe(makeStation("ST-003", "Saltwick Halt", 5)));
console.log("operator:", OPERATOR, "| limit:", MAX_ZONE);

console.log("distance:", Geometry.distance({ x: 0, y: 0 }, { x: 3, y: 4 }));
console.log("from the origin:", Geometry.fromOrigin({ x: 45, y: -10 }).toFixed(2));

try {
  makeStation("ST-004", "Far Halt", 9);
} catch (error) {
  console.log("rejected:", (error as RangeError).message);
}
