// A publish/subscribe emitter, written from scratch and then compared with
// the one in node:events. ESM module, run with `node event-emitter.mjs`.

import { EventEmitter } from 'node:events';

export class TinyEmitter {
  #listeners = new Map();

  on(event, listener) {
    if (!this.#listeners.has(event)) {
      this.#listeners.set(event, new Set());
    }
    this.#listeners.get(event).add(listener);
    return () => this.off(event, listener); // an unsubscribe handle
  }

  once(event, listener) {
    const wrapper = (...args) => {
      this.off(event, wrapper);
      listener(...args);
    };
    return this.on(event, wrapper);
  }

  off(event, listener) {
    this.#listeners.get(event)?.delete(listener);
  }

  emit(event, ...args) {
    const listeners = this.#listeners.get(event);
    if (!listeners) {
      return false;
    }
    // Copy first, so a listener that unsubscribes cannot disturb the walk.
    for (const listener of [...listeners]) {
      listener(...args);
    }
    return true;
  }

  listenerCount(event) {
    return this.#listeners.get(event)?.size ?? 0;
  }
}

const sensors = new TinyEmitter();

const unsubscribe = sensors.on('reading', (device, celsius) => {
  console.log(`  logger: ${device} at ${celsius}C`);
});

sensors.on('reading', (device, celsius) => {
  if (celsius > 30) {
    console.log(`  alarm: ${device} is too warm`);
  }
});

sensors.once('ready', () => console.log('  ready fired, once only'));

sensors.emit('ready');
sensors.emit('ready');
sensors.emit('reading', 'SNS-01', 21.4);
sensors.emit('reading', 'SNS-04', 31.2);

unsubscribe();
console.log('after unsubscribing, listeners left:', sensors.listenerCount('reading'));
sensors.emit('reading', 'SNS-07', 19.6);

console.log('\nnode:events does the same, with more around it');
const built = new EventEmitter();
built.on('error', (error) => console.log('  handled:', error.message));
built.on('reading', (value) => console.log('  built-in listener saw', value));
built.emit('reading', 18.2);
built.emit('error', new Error('sensor dropped out'));
console.log('  event names:', built.eventNames());
