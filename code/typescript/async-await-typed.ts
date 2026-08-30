// Promises with types: what async returns, how errors are typed, and how to
// run work concurrently.

interface Station {
  id: string;
  name: string;
  zone: number;
}

const NETWORK: Record<string, Station> = {
  "ST-001": { id: "ST-001", name: "Alder Cross", zone: 2 },
  "ST-002": { id: "ST-002", name: "Quill Wharf", zone: 3 },
};

const wait = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

// An async function always returns a Promise, even when the body returns a
// plain value.
async function fetchStation(id: string, ms = 50): Promise<Station> {
  await wait(ms);
  const station = NETWORK[id];
  if (station === undefined) {
    throw new Error(`no station with id ${id}`);
  }
  return station;
}

// Awaited<T> unwraps however many Promise layers there are.
type Fetched = Awaited<ReturnType<typeof fetchStation>>;

async function main(): Promise<void> {
  let started = Date.now();

  // Sequential: each await holds up the next call.
  const first: Fetched = await fetchStation("ST-001", 80);
  const second = await fetchStation("ST-002", 80);
  console.log(`${first.name}, ${second.name} in ~${Date.now() - started} ms`);

  // Concurrent: all() keeps the tuple's types, one per element.
  started = Date.now();
  const [a, b] = await Promise.all([fetchStation("ST-001", 80), fetchStation("ST-002", 80)]);
  console.log(`${a.name}, ${b.name} in ~${Date.now() - started} ms`);

  // A mixed tuple keeps each element's own type.
  const [station, count] = await Promise.all([fetchStation("ST-001"), Promise.resolve(42)]);
  console.log(`${station.name} / ${count.toFixed(0)}`);

  // allSettled gives a discriminated union per result.
  const settled = await Promise.allSettled([fetchStation("ST-001"), fetchStation("ST-999")]);
  for (const result of settled) {
    if (result.status === "fulfilled") {
      console.log("  fulfilled:", result.value.name);
    } else {
      console.log("  rejected:", (result.reason as Error).message);
    }
  }

  console.log("race:", (await Promise.race([fetchStation("ST-001", 20), fetchStation("ST-002", 90)])).name);
  console.log("any:", (await Promise.any([fetchStation("ST-999", 10).catch(() => Promise.reject(new Error("x"))), fetchStation("ST-002", 40)])).name);

  // A caught error is `unknown`, so it has to be narrowed before use.
  try {
    await fetchStation("ST-999");
  } catch (error: unknown) {
    if (error instanceof Error) {
      console.log("caught:", error.message);
    } else {
      console.log("caught something that is not an Error:", error);
    }
  }

  // Mapping over ids concurrently, with the element type preserved.
  const ids = ["ST-001", "ST-002"];
  const stations: Station[] = await Promise.all(ids.map((id) => fetchStation(id, 30)));
  console.log("mapped:", stations.map((s) => s.zone));

  // An async generator, consumed with for await.
  async function* readings(count: number): AsyncGenerator<number, void, undefined> {
    for (let index = 1; index <= count; index += 1) {
      await wait(10);
      yield Number((20 + index / 10).toFixed(1));
    }
  }
  const seen: number[] = [];
  for await (const value of readings(4)) {
    seen.push(value);
  }
  console.log("async generator:", seen);

  // A timeout, built from race.
  async function withTimeout<T>(work: Promise<T>, ms: number): Promise<T> {
    const timer = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`timed out after ${ms} ms`)), ms),
    );
    return Promise.race([work, timer]);
  }
  await withTimeout(fetchStation("ST-001", 200), 50).catch((error: Error) =>
    console.log("timeout:", error.message),
  );
}

void main();
