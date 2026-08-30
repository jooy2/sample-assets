// Promises: running work in sequence, in parallel, and handling the ones
// that fail.

const wait = (ms, value) => new Promise((resolve) => setTimeout(() => resolve(value), ms));
const fail = (ms, reason) => new Promise((_, reject) => setTimeout(() => reject(new Error(reason)), ms));

async function main() {
  let started = Date.now();

  // Sequential: each await holds up the next call.
  await wait(120, 'a');
  await wait(120, 'b');
  console.log(`sequential took ~${Date.now() - started} ms`);

  // Parallel: both are already running when they are awaited.
  started = Date.now();
  const [first, second] = await Promise.all([wait(120, 'a'), wait(120, 'b')]);
  console.log(`Promise.all gave ${first}${second} in ~${Date.now() - started} ms`);

  // all rejects as soon as any one does.
  try {
    await Promise.all([wait(50, 'ok'), fail(20, 'the upstream gave up')]);
  } catch (error) {
    console.log('Promise.all rejected with:', error.message);
  }

  // allSettled waits for every result, successful or not.
  const settled = await Promise.allSettled([wait(30, 'ok'), fail(10, 'nope')]);
  console.log(settled.map((result) => result.status).join(', '));
  console.log('reason:', settled.find((r) => r.status === 'rejected').reason.message);

  // race settles with the first result of either kind; any waits for the
  // first success.
  console.log('race:', await Promise.race([wait(80, 'slow'), wait(20, 'quick')]));
  console.log('any:', await Promise.any([fail(10, 'first failed'), wait(40, 'survivor')]));

  // Running a queue with a limit, rather than all at once.
  const limit = 2;
  const jobs = [1, 2, 3, 4, 5, 6].map((id) => () => wait(30, id));
  const results = [];
  const running = new Set();

  for (const job of jobs) {
    const promise = job().then((value) => {
      results.push(value);
      running.delete(promise);
    });
    running.add(promise);
    if (running.size >= limit) {
      await Promise.race(running);
    }
  }
  await Promise.all(running);
  console.log('processed two at a time:', results);
}

main().catch((error) => console.error('unhandled:', error));
