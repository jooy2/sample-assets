/**
 * reactive-store.js — a reactive state container with computed values,
 * fine-grained subscriptions, batching, middleware, time travel, and
 * structural change detection.
 *
 * No dependencies, no build step. Runs in a browser or in Node.
 *
 *   const store = createStore({ count: 0, items: [] });
 *   const double = store.computed((state) => state.count * 2);
 *   store.subscribe('count', (next, prev) => console.log(next, prev));
 *   store.commit((draft) => { draft.count += 1; });
 *
 * The design in one line: state is plain data, updates are functions of the
 * previous state, and subscribers are notified only for the paths that
 * actually changed.
 */

'use strict';

// ------------------------------------------------------------------- helpers

/** Deep-freeze an object so that a subscriber cannot mutate shared state. */
function deepFreeze(value) {
  if (value === null || typeof value !== 'object' || Object.isFrozen(value)) {
    return value;
  }
  Object.freeze(value);
  for (const key of Object.keys(value)) {
    deepFreeze(value[key]);
  }
  return value;
}

/** Structural equality, sufficient for JSON-shaped state. */
function equal(a, b) {
  if (Object.is(a, b)) return true;
  if (a === null || b === null) return false;
  if (typeof a !== 'object' || typeof b !== 'object') return false;

  const aIsArray = Array.isArray(a);
  if (aIsArray !== Array.isArray(b)) return false;

  if (aIsArray) {
    if (a.length !== b.length) return false;
    return a.every((item, index) => equal(item, b[index]));
  }

  const aKeys = Object.keys(a);
  const bKeys = Object.keys(b);
  if (aKeys.length !== bKeys.length) return false;
  return aKeys.every(
    (key) => Object.prototype.hasOwnProperty.call(b, key) && equal(a[key], b[key])
  );
}

/** A structured clone that keeps Date and Map, unlike JSON round-tripping. */
function clone(value) {
  if (value === null || typeof value !== 'object') return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (value instanceof Map) return new Map([...value].map(([k, v]) => [k, clone(v)]));
  if (value instanceof Set) return new Set([...value].map(clone));
  if (Array.isArray(value)) return value.map(clone);

  const out = {};
  for (const key of Object.keys(value)) {
    out[key] = clone(value[key]);
  }
  return out;
}

/** Read a dotted path out of an object, returning undefined rather than throwing. */
function readPath(source, path) {
  if (path === '') return source;
  let node = source;
  for (const segment of path.split('.')) {
    if (node === null || node === undefined) return undefined;
    node = node[segment];
  }
  return node;
}

/**
 * Every path whose value differs between two states, as dotted strings.
 * A change to `a.b.c` reports `a`, `a.b`, and `a.b.c`, so a subscriber to any
 * ancestor is notified too.
 */
function changedPaths(before, after, prefix = '', found = new Set()) {
  if (equal(before, after)) return found;

  if (prefix !== '') found.add(prefix);

  const bothObjects =
    before !== null &&
    after !== null &&
    typeof before === 'object' &&
    typeof after === 'object' &&
    Array.isArray(before) === Array.isArray(after);

  if (!bothObjects) return found;

  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  for (const key of keys) {
    const next = prefix === '' ? key : `${prefix}.${key}`;
    changedPaths(before[key], after[key], next, found);
  }
  return found;
}

// --------------------------------------------------------------------- store

/**
 * @typedef {Object} StoreOptions
 * @property {number} [historyLimit=50] How many past states to retain.
 * @property {boolean} [freeze=true]    Freeze state before handing it out.
 * @property {string}  [name='store']   Used in middleware logs.
 */

/**
 * Create a store.
 *
 * @param {object} initialState
 * @param {StoreOptions} [options]
 */
function createStore(initialState, options = {}) {
  const { historyLimit = 50, freeze = true, name = 'store' } = options;

  let state = freeze ? deepFreeze(clone(initialState)) : clone(initialState);

  /** @type {Map<string, Set<Function>>} path -> subscribers */
  const subscribers = new Map();
  /** @type {Array<Function>} */
  const middleware = [];
  /** @type {Array<{state: object, label: string}>} */
  const past = [];
  /** @type {Array<{state: object, label: string}>} */
  const future = [];
  /** @type {Set<object>} */
  const computeds = new Set();

  let batchDepth = 0;
  let batchedFrom = null;

  // ------------------------------------------------------------ notification

  function notify(before, after, label) {
    const paths = changedPaths(before, after);
    if (paths.size === 0) return;

    // '' is the wildcard: subscribers to the whole store.
    const targets = new Set(['']);
    for (const path of paths) targets.add(path);

    for (const computed of computeds) computed.invalidate();

    for (const target of targets) {
      const listeners = subscribers.get(target);
      if (!listeners) continue;

      const nextValue = readPath(after, target);
      const previousValue = readPath(before, target);
      for (const listener of [...listeners]) {
        try {
          listener(nextValue, previousValue, { path: target, label });
        } catch (error) {
          // A throwing subscriber must not stop the others.
          reportSubscriberError(error, target, label);
        }
      }
    }
  }

  function reportSubscriberError(error, path, label) {
    const message = `${name}: subscriber for "${path || '*'}" threw during "${label}"`;
    if (typeof console !== 'undefined' && console.error) {
      console.error(message, error);
    }
  }

  // ------------------------------------------------------------------- api

  const store = {
    /** The current state. Frozen unless the store was created with freeze:false. */
    get state() {
      return state;
    },

    /** Read a dotted path. */
    get(path = '') {
      return readPath(state, path);
    },

    /**
     * Apply a change. The recipe receives a mutable draft of the current
     * state; whatever it mutates (or returns) becomes the next state.
     *
     * @param {(draft: object) => object|void} recipe
     * @param {string} [label] Shown in history and middleware.
     */
    commit(recipe, label = recipe.name || 'commit') {
      const before = state;
      const draft = clone(state);
      const returned = recipe(draft);

      // A recipe either mutates the draft and returns nothing, or returns a
      // replacement state. Anything else is an arrow function with an
      // expression body -- `(draft) => draft.items.push(x)` returns a number --
      // and silently replacing the state with it is the worst possible
      // outcome, so it is an error instead.
      if (returned !== undefined && (returned === null || typeof returned !== 'object')) {
        throw new TypeError(
          `${name}: recipe for "${label}" returned ${typeof returned}; ` +
            'a recipe must mutate the draft and return nothing, or return a new state object'
        );
      }

      let next = returned === undefined ? draft : returned;

      for (const layer of middleware) {
        const replaced = layer({ name, label, before, next, store });
        if (replaced !== undefined) next = replaced;
      }

      if (equal(before, next)) return false;

      state = freeze ? deepFreeze(next) : next;

      past.push({ state: before, label });
      if (past.length > historyLimit) past.shift();
      future.length = 0;

      if (batchDepth > 0) {
        if (batchedFrom === null) batchedFrom = before;
        return true;
      }

      notify(before, state, label);
      return true;
    },

    /**
     * Run several commits and notify subscribers once, with the net change.
     * Nested batches collapse into the outermost one.
     */
    batch(work, label = 'batch') {
      batchDepth += 1;
      try {
        work(store);
      } finally {
        batchDepth -= 1;
        if (batchDepth === 0 && batchedFrom !== null) {
          const before = batchedFrom;
          batchedFrom = null;
          notify(before, state, label);
        }
      }
    },

    /**
     * Subscribe to a dotted path, or to '' for every change.
     * Returns an unsubscribe function.
     */
    subscribe(path, listener) {
      if (typeof path === 'function') {
        listener = path;
        path = '';
      }
      if (!subscribers.has(path)) subscribers.set(path, new Set());
      subscribers.get(path).add(listener);

      return function unsubscribe() {
        const listeners = subscribers.get(path);
        if (!listeners) return;
        listeners.delete(listener);
        if (listeners.size === 0) subscribers.delete(path);
      };
    },

    /** Subscribe and fire once immediately with the current value. */
    watch(path, listener) {
      const unsubscribe = store.subscribe(path, listener);
      listener(readPath(state, path), undefined, { path, label: 'initial' });
      return unsubscribe;
    },

    /**
     * A lazily-evaluated derived value, recomputed only after a change and
     * only when something asks for it.
     */
    computed(selector, { equals = equal } = {}) {
      let cached;
      let valid = false;

      const handle = {
        get value() {
          if (!valid) {
            const next = selector(state);
            if (!valid || !equals(cached, next)) cached = next;
            valid = true;
          }
          return cached;
        },
        invalidate() {
          valid = false;
        },
        dispose() {
          computeds.delete(handle);
        },
      };

      computeds.add(handle);
      return handle;
    },

    /** Insert a middleware layer. Returns a function that removes it. */
    use(layer) {
      middleware.push(layer);
      return function remove() {
        const index = middleware.indexOf(layer);
        if (index >= 0) middleware.splice(index, 1);
      };
    },

    /** Step backwards through history. */
    undo() {
      const entry = past.pop();
      if (!entry) return false;

      future.push({ state, label: entry.label });
      const before = state;
      state = entry.state;
      notify(before, state, `undo:${entry.label}`);
      return true;
    },

    /** Step forwards again after an undo. */
    redo() {
      const entry = future.pop();
      if (!entry) return false;

      past.push({ state, label: entry.label });
      const before = state;
      state = entry.state;
      notify(before, state, `redo:${entry.label}`);
      return true;
    },

    /** Labels of the states that undo would walk back through. */
    get history() {
      return past.map((entry) => entry.label);
    },

    /** Remove every subscriber and computed. */
    dispose() {
      subscribers.clear();
      computeds.clear();
      middleware.length = 0;
      past.length = 0;
      future.length = 0;
    },
  };

  return store;
}

// ---------------------------------------------------------------- middleware

/** Log every commit that changes something. */
function logger({ prefix = '' } = {}) {
  return function log({ name, label, before, next }) {
    const paths = [...changedPaths(before, next)].filter((p) => !p.includes('.'));
    if (paths.length === 0) return undefined;
    console.log(`${prefix}${name}/${label}: ${paths.join(', ')}`);
    return undefined;
  };
}

/** Reject a commit that leaves the state failing a predicate. */
function validate(predicate, message = 'invalid state') {
  return function check({ before, next, label }) {
    if (predicate(next)) return undefined;
    console.warn(`rejected "${label}": ${message}`);
    return before;
  };
}

/** Clamp a numeric path into a range on every commit. */
function clamp(path, low, high) {
  const segments = path.split('.');
  const last = segments.pop();

  return function apply({ next }) {
    let node = next;
    for (const segment of segments) {
      if (node === null || node === undefined) return undefined;
      node = node[segment];
    }
    if (node === null || node === undefined) return undefined;

    const value = node[last];
    if (typeof value !== 'number') return undefined;
    node[last] = Math.min(high, Math.max(low, value));
    return undefined;
  };
}

// ------------------------------------------------------------- demonstration

function demonstrate() {
  const store = createStore(
    {
      count: 0,
      user: { name: 'unset', roles: [] },
      items: [],
    },
    { name: 'demo' }
  );

  const log = [];
  store.use(({ label, before, next }) => {
    const paths = [...changedPaths(before, next)].filter((p) => !p.includes('.'));
    log.push(`${label} -> ${paths.join(',')}`);
    return undefined;
  });
  store.use(clamp('count', 0, 10));
  store.use(validate((s) => s.user.name !== '', 'name may not be empty'));

  const doubled = store.computed((s) => s.count * 2);
  const itemCount = store.computed((s) => s.items.length);

  const seen = [];
  const stopCount = store.subscribe('count', (next, prev) => {
    seen.push(`count ${prev} -> ${next}`);
  });
  store.subscribe('user.name', (next) => seen.push(`name = ${next}`));
  store.subscribe('', (_next, _prev, meta) => seen.push(`any: ${meta.path || '*'}`));

  console.log('--- commits ---');
  store.commit((draft) => {
    draft.count = 3;
  }, 'set-count');
  console.log('count', store.get('count'), 'doubled', doubled.value);

  store.commit((draft) => {
    draft.count = 99;
  }, 'overflow');
  console.log('clamped to', store.get('count'));

  store.commit((draft) => {
    draft.user.name = '';
  }, 'blank-name');
  console.log('name still', store.get('user.name'));

  console.log('\n--- batching ---');
  const before = seen.length;
  store.batch((s) => {
    s.commit((draft) => {
      draft.items.push({ id: 1, title: 'rope' });
    }, 'add');
    s.commit((draft) => {
      draft.items.push({ id: 2, title: 'lantern' });
    }, 'add');
    s.commit((draft) => {
      draft.user.name = 'Mira';
    }, 'name');
  }, 'setup');
  console.log(`three commits produced ${seen.length - before} notifications`);
  console.log('items', itemCount.value, 'name', store.get('user.name'));

  console.log('\n--- no-op commits ---');
  const changed = store.commit((draft) => {
    draft.count = draft.count;
  }, 'noop');
  console.log('commit reported change:', changed);

  console.log('\n--- history ---');
  console.log('labels', store.history.join(' | '));
  store.undo();
  console.log('after undo, name is', store.get('user.name'));
  store.redo();
  console.log('after redo, name is', store.get('user.name'));

  console.log('\n--- immutability ---');
  try {
    store.state.count = 500;
    console.log('mutation silently ignored; count is', store.get('count'));
  } catch (error) {
    console.log('mutation threw:', error.constructor.name);
  }

  stopCount();
  store.commit((draft) => {
    draft.count = 7;
  }, 'after-unsubscribe');
  console.log('count subscriber fired again:', seen.some((s) => s.includes('-> 7')));

  console.log('\n--- a recipe that returns the wrong thing ---');
  try {
    store.commit((draft) => draft.items.push({ id: 3 }), 'expression-body');
  } catch (error) {
    console.log(error.constructor.name + ':', error.message.split(';')[0]);
  }

  console.log('\n--- middleware log ---');
  console.log(log.join('\n'));
}

// ------------------------------------------------------------------- exports

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createStore,
    logger,
    validate,
    clamp,
    equal,
    clone,
    changedPaths,
    readPath,
    deepFreeze,
  };
}

if (typeof require !== 'undefined' && require.main === module) {
  demonstrate();
}
