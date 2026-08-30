// Regular expressions: matching, capturing, named groups, and replacing.

const logLines = [
  '203.0.113.183 - - [10/Nov/2025:00:02:25 +0000] "GET /api/v1/orders HTTP/2.0" 200 6776',
  '192.0.2.125 - imogen.hawthorne [10/Nov/2025:00:05:17 +0000] "POST /login HTTP/1.1" 302 312',
  'not a log line at all',
];

const LOG = /^(?<ip>\S+) \S+ (?<user>\S+) \[(?<time>[^\]]+)\] "(?<method>[A-Z]+) (?<path>\S+) [^"]+" (?<status>\d{3}) (?<bytes>\d+)$/;

for (const line of logLines) {
  const match = line.match(LOG);

  if (!match) {
    console.log('unparsed:', line);
    continue;
  }
  const { ip, user, method, path, status } = match.groups;
  console.log(`${status} ${method.padEnd(4)} ${path.padEnd(16)} from ${ip} as ${user}`);
}

// matchAll walks every match, with the capture groups of each.
const csv = 'Alder Cross,Amber,2;Quill Wharf,Cobalt,3;Saltwick Halt,Amber,5';
for (const { groups } of csv.matchAll(/(?<name>[^,;]+),(?<line>[^,;]+),(?<zone>\d+)/g)) {
  console.log(`  ${groups.name} is on ${groups.line}, zone ${groups.zone}`);
}

// Replacement with a function, and with $<name> references.
console.log('2025-11-03'.replace(/(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})/, '$<d>/$<m>/$<y>'));
console.log('zone 2, zone 5'.replaceAll(/zone (\d)/g, (_, digit) => `zone ${Number(digit) + 1}`));

// Splitting on a pattern, and keeping what was split on.
console.log('amber ,cobalt;  emerald'.split(/\s*[,;]\s*/));
console.log('one1two22three'.split(/(\d+)/));

// Lookahead and lookbehind.
console.log('1234567'.replace(/\B(?=(\d{3})+(?!\d))/g, ','));
console.log('price: $74.50'.match(/(?<=\$)[\d.]+/)?.[0]);

// Flags: i ignores case, m makes ^ and $ match per line, s lets . cross lines.
const text = 'Amber line\ncobalt LINE';
console.log(text.match(/^\w+ line$/gim));

// Anchors and escaping user input before building a pattern.
const escape = (input) => input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const needle = new RegExp(escape('a.b'), 'g');
console.log('literal dot only:', 'a.b axb a.b'.match(needle));

console.log('test is cheapest when the match is not needed:', /^\d{3}$/.test('404'));
