// A closure keeps the variables of the scope it was created in, long after
// that scope has returned.

function makeCounter(start = 0, step = 1) {
  let value = start; // private: only the returned functions can reach it

  return {
    next: () => (value += step),
    peek: () => value,
    reset: () => {
      value = start;
      return value;
    },
  };
}

const ticket = makeCounter(1000, 1);
console.log(ticket.next(), ticket.next(), ticket.next());
console.log('peek', ticket.peek());
console.log('reset', ticket.reset());

// Each call to the factory gets its own scope.
const other = makeCounter(1000);
console.log('independent:', other.next(), 'while the first is at', ticket.peek());

// Memoising: the cache lives in the closure.
function memoize(fn) {
  const cache = new Map();

  return (...args) => {
    const key = JSON.stringify(args);
    if (!cache.has(key)) {
      cache.set(key, fn(...args));
    }
    return cache.get(key);
  };
}

let calls = 0;
const slowSquare = (n) => {
  calls += 1;
  return n * n;
};
const fastSquare = memoize(slowSquare);

console.log(fastSquare(12), fastSquare(12), fastSquare(9));
console.log(`the underlying function ran ${calls} times, not 3`);

// The classic loop trap: `var` shares one binding, `let` makes one per turn.
const withVar = [];
for (var i = 0; i < 3; i++) {
  withVar.push(() => i);
}
const withLet = [];
for (let j = 0; j < 3; j++) {
  withLet.push(() => j);
}
console.log('var:', withVar.map((fn) => fn()));
console.log('let:', withLet.map((fn) => fn()));

// A closure over a partially applied argument.
const fareFor = (base) => (zones) => base + zones * 0.85;
console.log('three zones:', fareFor(2.4)(3).toFixed(2));
