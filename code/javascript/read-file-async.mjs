// Reading and writing files with the promise API, and streaming a large one
// line by line. Run with `node read-file-async.mjs`.

import { createReadStream } from 'node:fs';
import { mkdtemp, readFile, rm, writeFile, appendFile, stat } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const directory = await mkdtemp(join(tmpdir(), 'sample-assets-'));
const file = join(directory, 'stations.csv');

const rows = [
  'station,line,zone',
  'Alder Cross,Amber,2',
  'Quill Wharf,Cobalt,3',
  'Saltwick Halt,Amber,5',
  'Nether Gate,Emerald,2',
];

await writeFile(file, `${rows.join('\n')}\n`, 'utf8');
console.log(`wrote ${(await stat(file)).size} bytes to ${file}`);

// Small file: read the lot.
const whole = await readFile(file, 'utf8');
console.log('lines:', whole.trimEnd().split('\n').length);

// Large file: stream it, so only one line is held at a time.
const zones = [];
const lines = createInterface({ input: createReadStream(file, 'utf8'), crlfDelay: Infinity });

let header = true;
for await (const line of lines) {
  if (header) {
    header = false;
    continue;
  }
  const [name, lineName, zone] = line.split(',');
  zones.push(Number(zone));
  if (lineName === 'Amber') {
    console.log(`  Amber: ${name}`);
  }
}
console.log('average zone:', (zones.reduce((a, b) => a + b, 0) / zones.length).toFixed(2));

await appendFile(file, 'Vellin Halt,Slate,4\n', 'utf8');
console.log('after appending:', (await readFile(file, 'utf8')).trimEnd().split('\n').length, 'lines');

// Errors arrive as rejections, with a code worth checking.
try {
  await readFile(join(directory, 'missing.csv'), 'utf8');
} catch (error) {
  console.log('caught:', error.code);
}

await rm(directory, { recursive: true, force: true });
console.log('cleaned up');
