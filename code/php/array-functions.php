<?php

declare(strict_types=1);

// The array functions that replace most hand-written loops.

$stations = [
    ['name' => 'Alder Cross',    'line' => 'Amber',   'zone' => 2, 'platforms' => 2, 'stepFree' => true],
    ['name' => 'Quill Wharf',    'line' => 'Cobalt',  'zone' => 3, 'platforms' => 4, 'stepFree' => false],
    ['name' => 'Saltwick Halt',  'line' => 'Amber',   'zone' => 5, 'platforms' => 1, 'stepFree' => true],
    ['name' => 'Nether Gate',    'line' => 'Emerald', 'zone' => 2, 'platforms' => 3, 'stepFree' => true],
    ['name' => 'Bramble Fields', 'line' => 'Cobalt',  'zone' => 4, 'platforms' => 2, 'stepFree' => false],
];

$accessibleInner = array_column(
    array_filter($stations, fn (array $s): bool => $s['stepFree'] && $s['zone'] <= 3),
    'name'
);
sort($accessibleInner);
echo 'step free, zone 3 or closer: ', implode(', ', $accessibleInner), PHP_EOL;

$platforms = array_sum(array_column($stations, 'platforms'));
echo "platforms: {$platforms}", PHP_EOL;

// array_reduce folds the list into a single value.
$byLine = array_reduce($stations, function (array $groups, array $station): array {
    $groups[$station['line']][] = $station['name'];
    return $groups;
}, []);
print_r($byLine);

// array_column can build a lookup table in one call.
$zones = array_column($stations, 'zone', 'name');
echo 'Quill Wharf is in zone ', $zones['Quill Wharf'], PHP_EOL;

// There is no array_any before PHP 8.4, so a filter and a count stand in.
$deep = array_filter($stations, fn (array $s): bool => $s['zone'] === 5);
echo 'any in zone 5: ', var_export($deep !== [], true), PHP_EOL;
echo 'all have platforms: ', var_export(
    count(array_filter($stations, fn (array $s): bool => $s['platforms'] > 0)) === count($stations),
    true
), PHP_EOL;

// usort sorts in place with a comparison function; the spaceship operator
// compares two values in one step.
usort($stations, fn (array $a, array $b): int => [$a['zone'], $a['name']] <=> [$b['zone'], $b['name']]);
echo 'by zone: ', implode(', ', array_map(
    fn (array $s): string => "{$s['name']} ({$s['zone']})",
    $stations
)), PHP_EOL;

$numbers = [4, 8, 15, 16, 23, 42];
echo 'slice: ', implode(',', array_slice($numbers, 1, 3)), PHP_EOL;
echo 'reversed: ', implode(',', array_reverse($numbers)), PHP_EOL;
echo 'chunked: ', json_encode(array_chunk($numbers, 2)), PHP_EOL;
echo 'combined: ', json_encode(array_combine(['a', 'b'], [1, 2])), PHP_EOL;
echo 'unique: ', implode(',', array_unique([1, 2, 2, 3, 3, 3])), PHP_EOL;
echo 'search: ', var_export(in_array(23, $numbers, true), true), PHP_EOL;
echo 'key of 15: ', var_export(array_search(15, $numbers, true), true), PHP_EOL;
echo 'spread merge: ', implode(',', [...$numbers, 108]), PHP_EOL;
