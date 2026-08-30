// Generators produce values on demand; the iterator protocol is what
// for...of and spread actually use.

function* fibonacci() {
  let [previous, current] = [0n, 1n];

  while (true) {
    yield current;
    [previous, current] = [current, previous + current];
  }
}

function* take(iterable, count) {
  let taken = 0;
  for (const value of iterable) {
    if (taken++ >= count) {
      return;
    }
    yield value;
  }
}

function* traced(iterable, log) {
  for (const value of iterable) {
    log.push(value);
    yield value;
  }
}

console.log([...take(fibonacci(), 12)].map(String).join(' '));

function* naturals() {
  let n = 1;
  while (true) {
    yield n++;
  }
}

function* multiplesOfSeven(source) {
  for (const value of source) {
    if (value % 7 === 0) {
      yield value;
    }
  }
}

const log = [];
const firstThree = [...take(multiplesOfSeven(traced(naturals(), log)), 3)];
console.log('multiples of seven:', firstThree);
console.log(`the source was pulled ${log.length} times, not infinitely`);

// A generator can receive values back through next().
function* accumulator() {
  let total = 0;
  while (true) {
    const added = yield total;
    total += added ?? 0;
  }
}
const sum = accumulator();
sum.next();
console.log(sum.next(10).value, sum.next(5).value, sum.next(100).value);

// Any object becomes iterable by defining Symbol.iterator.
const network = {
  stations: ['Alder Cross', 'Quill Wharf', 'Saltwick Halt'],
  *[Symbol.iterator]() {
    for (const station of this.stations) {
      yield station.toUpperCase();
    }
  },
};
console.log([...network]);
for (const station of network) {
  console.log(' ', station);
}

// yield* delegates to another iterable.
function* allLines() {
  yield 'Amber';
  yield* ['Cobalt', 'Emerald'];
}
console.log([...allLines()]);
