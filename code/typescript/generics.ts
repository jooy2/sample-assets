// Generics: type parameters, constraints, defaults, and inference.

interface Identifiable {
  id: number;
}

class Repository<T extends Identifiable> {
  private readonly items = new Map<number, T>();

  add(item: T): this {
    if (this.items.has(item.id)) {
      throw new Error(`id ${item.id} is already taken`);
    }
    this.items.set(item.id, item);
    return this;
  }

  find(id: number): T | undefined {
    return this.items.get(id);
  }

  where(predicate: (item: T) => boolean): T[] {
    return [...this.items.values()].filter(predicate);
  }

  get size(): number {
    return this.items.size;
  }
}

interface Product extends Identifiable {
  name: string;
  price: number;
}

// A generic function infers its type argument from the call.
function first<T>(values: readonly T[], fallback: T): T {
  return values.length > 0 ? values[0]! : fallback;
}

// keyof plus a type parameter makes a type-safe property getter.
function pluck<T, K extends keyof T>(items: readonly T[], key: K): T[K][] {
  return items.map((item) => item[key]);
}

function largestBy<T>(items: readonly T[], key: (item: T) => number): T | undefined {
  return items.reduce<T | undefined>(
    (best, next) => (best === undefined || key(next) > key(best) ? next : best),
    undefined,
  );
}

// A default type parameter, and a constraint that refers to another one.
function groupBy<T, K extends string | number = string>(
  items: readonly T[],
  key: (item: T) => K,
): Record<K, T[]> {
  const groups = {} as Record<K, T[]>;
  for (const item of items) {
    (groups[key(item)] ??= []).push(item);
  }
  return groups;
}

const repository = new Repository<Product>()
  .add({ id: 1, name: "Matte Ceramic Mug", price: 12.5 })
  .add({ id: 2, name: "Bamboo Desk Mat", price: 32 })
  .add({ id: 3, name: "Cast Iron Skillet", price: 59 });

console.log(repository.find(2)?.name);
console.log("missing:", repository.find(99));
console.log("over 20:", repository.where((p) => p.price > 20).map((p) => p.name));
console.log("size:", repository.size);

const products = repository.where(() => true);
console.log("names:", pluck(products, "name"));
console.log("prices:", pluck(products, "price"));
console.log("dearest:", largestBy(products, (p) => p.price)?.name);
console.log("first of none:", first([], "fallback"));

console.log(
  "grouped:",
  Object.keys(groupBy(products, (p) => (p.price > 20 ? "dear" : "cheap"))),
);

try {
  repository.add({ id: 1, name: "Duplicate", price: 0 });
} catch (error) {
  console.log("rejected:", (error as Error).message);
}
