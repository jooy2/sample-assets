// Debounce waits for the noise to stop; throttle lets one call through per
// interval. They are not the same thing.

function debounce(fn, delay) {
  let timer;

  const debounced = (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
  debounced.cancel = () => clearTimeout(timer);
  return debounced;
}

function throttle(fn, interval) {
  let last = 0;
  let trailing;

  return (...args) => {
    const now = Date.now();

    if (now - last >= interval) {
      last = now;
      fn(...args);
      return;
    }
    // Keep the final call so the last value is not lost.
    clearTimeout(trailing);
    trailing = setTimeout(() => {
      last = Date.now();
      fn(...args);
    }, interval - (now - last));
  };
}

const debouncedCalls = [];
const throttledCalls = [];

const onSearch = debounce((query) => debouncedCalls.push(query), 60);
const onScroll = throttle((offset) => throttledCalls.push(offset), 60);

// Fire a burst of events 20 ms apart.
let tick = 0;
const timer = setInterval(() => {
  tick += 1;
  onSearch(`query-${tick}`);
  onScroll(tick * 100);

  if (tick === 8) {
    clearInterval(timer);

    setTimeout(() => {
      console.log('8 events, 20 ms apart, over ~160 ms');
      console.log('debounced ran:', debouncedCalls, '(only after the burst ended)');
      console.log('throttled ran:', throttledCalls, '(at most one per 60 ms)');
    }, 150);
  }
}, 20);

// A cancelled debounce never fires at all.
const abandoned = debounce(() => console.log('this never prints'), 30);
abandoned('ignored');
abandoned.cancel();
