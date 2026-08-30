// The array methods that replace most hand-written loops.

const stations = [
  { name: 'Alder Cross', line: 'Amber', zone: 2, platforms: 2, stepFree: true },
  { name: 'Quill Wharf', line: 'Cobalt', zone: 3, platforms: 4, stepFree: false },
  { name: 'Saltwick Halt', line: 'Amber', zone: 5, platforms: 1, stepFree: true },
  { name: 'Nether Gate', line: 'Emerald', zone: 2, platforms: 3, stepFree: true },
  { name: 'Bramble Fields', line: 'Cobalt', zone: 4, platforms: 2, stepFree: false },
];

const accessibleInner = stations
  .filter((station) => station.stepFree && station.zone <= 3)
  .map((station) => station.name)
  .sort();
console.log('step free, zone 3 or closer:', accessibleInner);

const totalPlatforms = stations.reduce((sum, station) => sum + station.platforms, 0);
console.log('platforms:', totalPlatforms);

const byLine = stations.reduce((groups, station) => {
  (groups[station.line] ??= []).push(station.name);
  return groups;
}, {});
console.log('by line:', byLine);

// Object.groupBy does the same thing in one call.
console.log('grouped:', Object.groupBy(stations, (station) => station.line));

console.log('any in zone 5:', stations.some((station) => station.zone === 5));
console.log('all have platforms:', stations.every((station) => station.platforms > 0));
console.log('first deep station:', stations.find((station) => station.zone > 4)?.name);
console.log('its index:', stations.findIndex((station) => station.zone > 4));
console.log('last step free:', stations.findLast((station) => station.stepFree)?.name);

// Sorting mutates, so copy first; toSorted returns a new array instead.
const byZone = stations.toSorted((a, b) => a.zone - b.zone || a.name.localeCompare(b.name));
console.log('by zone:', byZone.map((station) => `${station.name} (${station.zone})`));

console.log('flat:', [[1, 2], [3, [4, 5]]].flat(2));
console.log('flatMap:', stations.flatMap((station) => station.name.split(' ')));
console.log('slice vs splice:', stations.slice(0, 2).map((s) => s.name));
console.log('at(-1):', stations.at(-1).name);
console.log('from a length:', Array.from({ length: 5 }, (_, index) => index * index));
console.log('unique:', [...new Set([1, 2, 2, 3, 3, 3])]);
