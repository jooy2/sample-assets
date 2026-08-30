<?php

declare(strict_types=1);

// A generator produces values one at a time, so a sequence can be endless
// or larger than memory.

function fibonacci(): Generator
{
    [$previous, $current] = [0, 1];

    while (true) {
        yield $current;
        [$previous, $current] = [$current, $previous + $current];
    }
}

function take(iterable $source, int $count): Generator
{
    $taken = 0;
    foreach ($source as $value) {
        if ($taken++ >= $count) {
            return;
        }
        yield $value;
    }
}

/** Reads a file one line at a time instead of loading all of it. */
function readLines(string $path): Generator
{
    $handle = fopen($path, 'rb');
    if ($handle === false) {
        throw new RuntimeException("cannot open {$path}");
    }
    try {
        while (($line = fgets($handle)) !== false) {
            yield rtrim($line, "\r\n");
        }
    } finally {
        fclose($handle);
    }
}

echo implode(' ', iterator_to_array(take(fibonacci(), 12))), PHP_EOL;

// Keys can be yielded too.
function zones(): Generator
{
    yield 'Alder Cross' => 2;
    yield 'Quill Wharf' => 3;
    yield 'Saltwick Halt' => 5;
}

foreach (zones() as $station => $zone) {
    echo "  {$station} sits in zone {$zone}", PHP_EOL;
}

// yield from delegates to another iterable, keeping the laziness.
function allLines(): Generator
{
    yield 'Amber';
    yield from ['Cobalt', 'Emerald'];
    return 'done'; // available through getReturn()
}

$lines = allLines();
foreach ($lines as $line) {
    echo "  {$line}", PHP_EOL;
}
echo 'return value: ', $lines->getReturn(), PHP_EOL;

// send() passes a value back into the generator at the yield.
function accumulator(): Generator
{
    $total = 0;
    while (true) {
        $added = yield $total;
        $total += $added ?? 0;
    }
}
$sum = accumulator();
$sum->current();
echo $sum->send(10), ' ', $sum->send(5), ' ', $sum->send(100), PHP_EOL;

// Reading a file lazily: memory stays flat however large the file is.
$path = tempnam(sys_get_temp_dir(), 'sample-assets-');
file_put_contents($path, implode(PHP_EOL, [
    'station,line,zone',
    'Alder Cross,Amber,2',
    'Quill Wharf,Cobalt,3',
    'Saltwick Halt,Amber,5',
]));

$total = 0;
foreach (take(readLines($path), 100) as $index => $line) {
    if ($index === 0) {
        continue;
    }
    $total += (int) explode(',', $line)[2];
}
echo "zones add up to {$total}", PHP_EOL;
unlink($path);
