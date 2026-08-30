// Pulling values out of arrays and objects, with defaults, renaming, and
// rest elements.

const station = {
  id: 'ST-001',
  name: 'Alder Cross',
  line: 'Amber',
  zone: 2,
  location: { gridX: 45, gridY: -10 },
  platforms: [1, 2],
};

// Rename, supply a default, and collect the rest.
const { name, line: lineName, opened = 'unknown', ...others } = station;
console.log(name, lineName, opened);
console.log('the rest:', Object.keys(others));

// Nested, in one statement.
const { location: { gridX, gridY }, platforms: [firstPlatform] } = station;
console.log(`grid ${gridX},${gridY}, first platform ${firstPlatform}`);

const [head, second, ...tail] = ['Amber', 'Cobalt', 'Emerald', 'Crimson'];
console.log({ head, second, tail });

// Swapping without a temporary.
let a = 1;
let b = 2;
[a, b] = [b, a];
console.log({ a, b });

// Destructured parameters, with a default for the whole object.
function describe({ name: stationName, zone = 1, stepFree = false } = {}) {
  return `${stationName ?? 'unnamed'} in zone ${zone}${stepFree ? ', step free' : ''}`;
}
console.log(describe(station));
console.log(describe({ name: 'Vellin Halt', stepFree: true }));
console.log(describe());

// Destructuring in a loop, and over Object.entries.
const zones = { 'Alder Cross': 2, 'Quill Wharf': 3, 'Saltwick Halt': 5 };
for (const [stationName, zone] of Object.entries(zones)) {
  console.log(`  ${stationName} -> zone ${zone}`);
}

// Returning several values as an object keeps the call site readable.
function splitSeconds(total) {
  return { hours: Math.floor(total / 3600), minutes: Math.floor((total % 3600) / 60), seconds: total % 60 };
}
const { hours, minutes } = splitSeconds(9045);
console.log(`${hours}h ${minutes}m`);
