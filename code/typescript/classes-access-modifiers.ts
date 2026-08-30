// Classes: access modifiers, parameter properties, abstract members, and
// the difference between TypeScript's `private` and JavaScript's `#`.

abstract class Vehicle {
  // A parameter property declares and assigns in one place.
  constructor(
    public readonly name: string,
    protected capacity: number,
    private serial: string = `V-${Math.floor(Math.random() * 1000)}`,
  ) {}

  // An abstract member must be implemented by every subclass.
  abstract describe(): string;

  // protected is visible to subclasses, private only here.
  protected seats(): number {
    return this.capacity;
  }

  getSerial(): string {
    return this.serial;
  }

  static built = 0;

  static register(): void {
    Vehicle.built += 1;
  }
}

class Tram extends Vehicle {
  // #charge is private at runtime: it is not a property at all from outside.
  #charge = 100;

  constructor(
    name: string,
    capacity: number,
    public readonly line: string,
  ) {
    super(name, capacity);
    Vehicle.register();
  }

  drain(amount: number): this {
    this.#charge = Math.max(0, this.#charge - amount);
    return this;
  }

  get chargeLabel(): string {
    return `${this.#charge}% charged`;
  }

  describe(): string {
    // seats() is protected, so this works; serial is private, so it does not.
    return `${this.name} carries ${this.seats()} on the ${this.line} line, ${this.chargeLabel}`;
  }
}

class Ferry extends Vehicle {
  constructor(name: string, capacity: number) {
    super(name, capacity);
    Vehicle.register();
  }

  describe(): string {
    return `${this.name} carries ${this.seats()} across the harbour`;
  }
}

// An interface can describe a class's instance side.
interface Trackable {
  route: readonly string[];
  arriveAt(stop: string): void;
}

class TrackedTram extends Tram implements Trackable {
  private readonly stops: string[] = [];

  get route(): readonly string[] {
    return this.stops;
  }

  arriveAt(stop: string): void {
    this.stops.push(stop);
  }
}

const tram = new TrackedTram("Tram 14", 180, "Amber");
tram.drain(35);
tram.arriveAt("Alder Cross");
tram.arriveAt("Quill Wharf");

console.log(tram.describe());
console.log("route:", tram.route.join(" -> "));
console.log("serial:", tram.getSerial());

const ferry = new Ferry("Harbour Ferry", 240);
console.log(ferry.describe());

console.log("built:", Vehicle.built);
console.log("is a Vehicle:", tram instanceof Vehicle);

// TypeScript's `private` is erased; `#` survives into JavaScript.
console.log("own keys:", Object.keys(tram));
// tram.capacity;   // error: 'capacity' is protected
// tram.#charge;    // error: private and not accessible outside the class

// abstract classes cannot be instantiated.
// new Vehicle("Generic", 10);   // error: cannot create an instance of an abstract class
