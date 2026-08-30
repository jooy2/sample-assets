// Classes: fields, private members, getters, static members, and extends.

class Vehicle {
  static #built = 0; // private static, shared by the class

  #serial; // private instance field

  constructor(name, capacity) {
    this.name = name;
    this.capacity = capacity;
    Vehicle.#built += 1;
    this.#serial = `V-${String(Vehicle.#built).padStart(3, '0')}`;
  }

  get serial() {
    return this.#serial;
  }

  get label() {
    return `${this.name} (${this.capacity} seats)`;
  }

  describe() {
    return `${this.label}, serial ${this.serial}`;
  }

  static get built() {
    return Vehicle.#built;
  }
}

class Tram extends Vehicle {
  #chargePercent = 100;

  constructor(name, capacity, line) {
    super(name, capacity); // must run before `this` is touched
    this.line = line;
  }

  drain(amount) {
    this.#chargePercent = Math.max(0, this.#chargePercent - amount);
    return this;
  }

  get chargeLabel() {
    return `${this.#chargePercent}% charged`;
  }

  describe() {
    return `${super.describe()} on the ${this.line} line, ${this.chargeLabel}`;
  }

  // Controls what `instanceof` and String() do.
  toString() {
    return `Tram(${this.name})`;
  }
}

const tram = new Tram('Tram 14', 180, 'Amber').drain(35);
const ferry = new Vehicle('Harbour Ferry', 240);

console.log(tram.describe());
console.log(ferry.describe());
console.log(`${tram}`);
console.log('built so far:', Vehicle.built);
console.log('tram is a Vehicle:', tram instanceof Vehicle);
console.log('ferry is a Tram:', ferry instanceof Tram);

// Private fields are not properties, so they never show up from outside.
console.log('own keys:', Object.keys(tram));
console.log('chargePercent from outside:', tram.chargePercent);
