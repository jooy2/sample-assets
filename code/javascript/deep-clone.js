// Copying an object: shallow, JSON round trip, structuredClone, and by hand.

const original = {
  name: 'Alder Cross',
  zone: 2,
  location: { gridX: 45, gridY: -10 },
  platforms: [1, 2],
  opened: new Date('1978-04-11T00:00:00Z'),
  lines: new Set(['Amber']),
  fares: new Map([['peak', 3.4]]),
};

// A spread copies one level: nested objects are still shared.
const shallow = { ...original };
shallow.location.gridX = 999;
console.log('shallow shares the nested object:', original.location.gridX);
original.location.gridX = 45;

// A JSON round trip is deep, but drops or flattens anything JSON cannot hold.
const viaJson = JSON.parse(JSON.stringify(original));
console.log('JSON clone: date became a', typeof viaJson.opened,
  '| set became', JSON.stringify(viaJson.lines));

// structuredClone handles Date, Map, Set, and cycles, but not functions.
const structured = structuredClone(original);
structured.location.gridX = 111;
console.log('structuredClone is independent:', original.location.gridX);
console.log('  date survives:', structured.opened instanceof Date);
console.log('  map survives:', structured.fares.get('peak'));

const cyclic = { name: 'Amber' };
cyclic.self = cyclic;
console.log('  cycles survive:', structuredClone(cyclic).self.name);

try {
  structuredClone({ fn: () => 1 });
} catch (error) {
  console.log('  functions do not:', error.name);
}

// By hand, when the rules have to be your own.
function deepClone(value, seen = new WeakMap()) {
  if (value === null || typeof value !== 'object') {
    return value;
  }
  if (seen.has(value)) {
    return seen.get(value);
  }
  if (value instanceof Date) {
    return new Date(value);
  }
  if (value instanceof Map) {
    const copy = new Map();
    seen.set(value, copy);
    for (const [key, held] of value) {
      copy.set(deepClone(key, seen), deepClone(held, seen));
    }
    return copy;
  }
  if (value instanceof Set) {
    const copy = new Set();
    seen.set(value, copy);
    for (const held of value) {
      copy.add(deepClone(held, seen));
    }
    return copy;
  }

  const copy = Array.isArray(value) ? [] : Object.create(Object.getPrototypeOf(value));
  seen.set(value, copy);
  for (const [key, held] of Object.entries(value)) {
    copy[key] = deepClone(held, seen);
  }
  return copy;
}

const manual = deepClone(original);
manual.platforms.push(3);
console.log('hand written clone is independent:', original.platforms.length, manual.platforms.length);
console.log('and keeps the types:', manual.opened instanceof Date, manual.lines instanceof Set);
