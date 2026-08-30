// Standard decorators (TypeScript 5): functions that wrap a class, a
// method, a field, or an accessor at definition time.

type Method<T, A extends unknown[], R> = (this: T, ...args: A) => R;

/** A method decorator that logs every call. */
function logged<T, A extends unknown[], R>(
  target: Method<T, A, R>,
  context: ClassMethodDecoratorContext,
): Method<T, A, R> {
  const name = String(context.name);
  return function (this: T, ...args: A): R {
    console.log(`  -> ${name}(${args.map((a) => JSON.stringify(a)).join(", ")})`);
    const result = target.call(this, ...args);
    console.log(`  <- ${name} returned ${JSON.stringify(result)}`);
    return result;
  };
}

/** A decorator factory: arguments outside, the decorator inside. */
function retry(attempts: number) {
  return function <T, A extends unknown[], R>(
    target: Method<T, A, R>,
    context: ClassMethodDecoratorContext,
  ): Method<T, A, R> {
    return function (this: T, ...args: A): R {
      let lastError: unknown;
      for (let attempt = 1; attempt <= attempts; attempt += 1) {
        try {
          return target.call(this, ...args);
        } catch (error) {
          lastError = error;
          console.log(`  attempt ${attempt} of ${String(context.name)} failed`);
        }
      }
      throw lastError;
    };
  };
}

/** A field decorator returns an initialiser, so it can transform the value. */
function clamped(low: number, high: number) {
  return function (_target: undefined, _context: ClassFieldDecoratorContext) {
    return function (initial: number): number {
      return Math.min(high, Math.max(low, initial));
    };
  };
}

/** A class decorator can replace the class with a subclass of it. */
function tracked<T extends new (...args: any[]) => object>(
  target: T,
  context: ClassDecoratorContext,
): T {
  let instances = 0;

  const wrapped = class extends target {
    constructor(...args: any[]) {
      super(...args);
      instances += 1;
    }

    static get instances(): number {
      return instances;
    }
  };

  Object.defineProperty(wrapped, "name", { value: String(context.name) });
  return wrapped;
}

@tracked
class Sensor {
  @clamped(1, 6)
  zone = 9;

  private failures = 0;

  constructor(public readonly id: string) {}

  @logged
  read(offset: number): number {
    return Number((20 + offset).toFixed(1));
  }

  @retry(3)
  flaky(): string {
    this.failures += 1;
    if (this.failures < 3) {
      throw new Error("the upstream gave up");
    }
    return `succeeded on attempt ${this.failures}`;
  }
}

const sensor = new Sensor("SNS-01");
console.log("clamped field:", sensor.zone);
sensor.read(1.4);
console.log(sensor.flaky());
// The decorator added a static, which the declared type does not know about.
console.log("instances:", (Sensor as typeof Sensor & { instances: number }).instances);
console.log("class name is preserved:", Sensor.name);
