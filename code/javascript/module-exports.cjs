// CommonJS: module.exports, require, and the module wrapper Node puts
// around every file. Run with `node module-exports.cjs`.

'use strict';

// A module's top level runs once, the first time it is required.
console.log('this module is', module.filename.split('/').pop());
console.log('required directly:', require.main === module);

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function titleCase(text) {
  return text.replace(/\b\w/g, (character) => character.toUpperCase());
}

class Stopwatch {
  constructor() {
    this.started = process.hrtime.bigint();
  }

  elapsedMs() {
    return Number(process.hrtime.bigint() - this.started) / 1e6;
  }
}

// Named exports: everything hangs off the exports object.
module.exports = { slugify, titleCase, Stopwatch };

// A single default-style export would instead be:
//   module.exports = slugify;
// and the two cannot be mixed, which is the usual CommonJS trap.

module.exports.VERSION = '1.0.0';

if (require.main === module) {
  const { slugify: slug, titleCase: title, Stopwatch: Watch } = module.exports;

  console.log(slug('  Alder Cross / Quill Wharf  '));
  console.log(title('quill moor station'));

  const watch = new Watch();
  let total = 0;
  for (let i = 0; i < 1e6; i += 1) {
    total += i;
  }
  console.log(`summed ${total} in ${watch.elapsedMs().toFixed(2)} ms`);

  // Requiring the same file twice returns the cached exports object.
  const again = require('./module-exports.cjs');
  console.log('cached:', again === module.exports);
  console.log('version:', again.VERSION);
}
