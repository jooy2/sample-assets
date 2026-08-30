// ?. stops at the first null or undefined; ?? only falls back on those two,
// which || does not.

const network = {
  name: 'Amber',
  operator: { name: 'Veranix Transit', contact: { email: 'ops@example.com' } },
  stations: [
    { name: 'Alder Cross', zone: 2, facilities: { stepFree: true } },
    { name: 'Quill Wharf', zone: 0 },
  ],
  fares: null,
};

console.log(network.operator?.contact?.email);
console.log(network.fares?.peak?.zone1);            // undefined, and no throw
console.log(network.stations?.[1]?.facilities?.stepFree);
console.log(network.refresh?.());                    // the call is skipped entirely

// || treats every falsy value as missing; ?? only null and undefined.
const zone = network.stations[1].zone;
console.log('with ||:', zone || 'unknown');   // 0 is falsy, so this is wrong
console.log('with ??:', zone ?? 'unknown');   // 0 survives

for (const value of [0, '', false, NaN, null, undefined]) {
  console.log(`${String(value).padEnd(9)} || -> ${value || 'fallback'}   ?? -> ${value ?? 'fallback'}`);
}

// ??= assigns only when the target is null or undefined.
const settings = { retries: 0, timeout: null };
settings.retries ??= 3;
settings.timeout ??= 5000;
settings.label ??= 'default';
console.log(settings);

// Optional chaining on the way into a function call and a dynamic key.
const key = 'stations';
console.log('count:', network?.[key]?.length ?? 0);

function fareFor(station) {
  // One guard instead of a chain of ifs.
  const stepFree = station?.facilities?.stepFree ?? false;
  return `${station?.name ?? 'unknown'}: ${stepFree ? 'step free' : 'stairs only'}`;
}
console.log(fareFor(network.stations[0]));
console.log(fareFor(network.stations[1]));
console.log(fareFor(undefined));

// Short-circuiting means the right side never runs.
let touched = 0;
const bump = () => (touched += 1);
network.fares?.[bump()];
console.log('bump was never called:', touched === 0);
