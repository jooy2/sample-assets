// JSON.parse and JSON.stringify, including the reviver and replacer hooks
// that most code never reaches for.

const orders = [
  {
    orderId: 'ORD-10001',
    userId: 82,
    total: 104.35,
    status: 'delivered',
    shippedAt: new Date('2025-11-03T09:15:00Z'),
    internalNote: 'do not ship to the customer',
  },
  { orderId: 'ORD-10002', userId: 6, total: 42.99, status: 'pending', shippedAt: null },
];

// A replacer can drop or rewrite fields on the way out.
const json = JSON.stringify(
  orders,
  (key, value) => (key === 'internalNote' ? undefined : value),
  2,
);
console.log(json);

// A reviver rebuilds richer types on the way in.
const parsed = JSON.parse(json, (key, value) =>
  key === 'shippedAt' && typeof value === 'string' ? new Date(value) : value);

console.log('\nshippedAt is a Date again:', parsed[0].shippedAt instanceof Date);
console.log('total:', parsed.reduce((sum, order) => sum + order.total, 0).toFixed(2));

// toJSON on a class decides its own serialised shape.
class Money {
  constructor(cents, currency = 'USD') {
    this.cents = cents;
    this.currency = currency;
  }

  toJSON() {
    return `${(this.cents / 100).toFixed(2)} ${this.currency}`;
  }
}
console.log(JSON.stringify({ subtotal: new Money(7450), shipping: new Money(499) }));

// Only a subset of values survives a round trip.
console.log(JSON.stringify({
  fn: () => 1,
  undef: undefined,
  sym: Symbol('x'),
  nan: NaN,
  inf: Infinity,
  set: new Set([1, 2]),
}));

try {
  JSON.parse('{"unterminated": ');
} catch (error) {
  console.log('caught:', error.name, '-', error.message);
}

// Circular structures need a seen-set.
const network = { name: 'Amber' };
network.self = network;
const seen = new WeakSet();
console.log(JSON.stringify(network, (key, value) => {
  if (typeof value === 'object' && value !== null) {
    if (seen.has(value)) return '[circular]';
    seen.add(value);
  }
  return value;
}));
