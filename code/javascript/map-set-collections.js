// Map and Set, and where they beat a plain object or an array.

const zones = new Map([
  ['Alder Cross', 2],
  ['Quill Wharf', 3],
  ['Saltwick Halt', 5],
]);

zones.set('Nether Gate', 2);
console.log('size', zones.size, '| has Quill Wharf:', zones.has('Quill Wharf'));
console.log('get missing:', zones.get('Vellin Halt'));

// A Map keeps insertion order and accepts any key type, including objects.
const amber = { line: 'Amber' };
const byObject = new Map([[amber, ['Alder Cross', 'Saltwick Halt']]]);
console.log('keyed by an object:', byObject.get(amber));

for (const [station, zone] of zones) {
  console.log(`  ${station.padEnd(15)} zone ${zone}`);
}

console.log('keys:', [...zones.keys()].slice(0, 2));
console.log('values sum:', [...zones.values()].reduce((a, b) => a + b, 0));
console.log('as an object:', Object.fromEntries(zones));

zones.delete('Saltwick Halt');
console.log('after delete:', zones.size);

// A Set holds each value once, and keeps insertion order.
const lines = new Set(['Amber', 'Cobalt', 'Amber', 'Emerald']);
console.log('unique lines:', [...lines]);
console.log('has Slate:', lines.has('Slate'));

const accessible = new Set(['Amber', 'Emerald', 'Crimson']);
console.log('intersection:', [...lines].filter((line) => accessible.has(line)));
console.log('difference:', [...lines].filter((line) => !accessible.has(line)));
console.log('union:', [...new Set([...lines, ...accessible])]);

// Deduplicating objects needs a key, since two objects are never equal.
const readings = [
  { device: 'SNS-01', celsius: 21.4 },
  { device: 'SNS-02', celsius: 19.8 },
  { device: 'SNS-01', celsius: 21.9 },
];
const latest = new Map(readings.map((reading) => [reading.device, reading]));
console.log('one per device:', [...latest.values()]);

// WeakMap holds its keys weakly, so entries vanish with the object.
const metadata = new WeakMap();
metadata.set(amber, { colour: '#c8a02a' });
console.log('weak lookup:', metadata.get(amber));
