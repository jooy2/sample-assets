<?php

declare(strict_types=1);

// Named arguments let a call skip optional parameters and say what each
// value means, without changing the function.

function makeStation(
    string $name,
    string $line = 'Amber',
    int $zone = 1,
    int $platforms = 2,
    bool $stepFree = false,
    bool $interchange = false,
): array {
    return compact('name', 'line', 'zone', 'platforms', 'stepFree', 'interchange');
}

// Positional: every earlier parameter has to be spelled out.
print_r(makeStation('Alder Cross', 'Amber', 2, 2, true));

// Named: only what differs from the defaults.
print_r(makeStation('Quill Wharf', zone: 3, stepFree: true, interchange: true));

// The two can be mixed, as long as the positional ones come first.
print_r(makeStation('Saltwick Halt', 'Amber', zone: 5));

// Order does not matter once arguments are named.
print_r(makeStation(stepFree: true, name: 'Nether Gate', zone: 2));

// Named arguments work with constructors and built-in functions too.
final class Fare
{
    public function __construct(
        public readonly float $base = 2.40,
        public readonly float $perZone = 0.85,
        public readonly bool $offPeak = false,
    ) {
    }

    public function forZones(int $zones): float
    {
        $total = $this->base + $zones * $this->perZone;
        return $this->offPeak ? $total * 0.8 : $total;
    }
}

$offPeak = new Fare(offPeak: true);
printf("three zones off peak: %.2f%s", $offPeak->forZones(3), PHP_EOL);

echo str_pad(string: 'zone', length: 10, pad_string: '.', pad_type: STR_PAD_RIGHT), '|', PHP_EOL;
echo json_encode(value: ['a' => 1], flags: JSON_PRETTY_PRINT), PHP_EOL;
echo implode(separator: ' -> ', array: ['Amber', 'Cobalt']), PHP_EOL;

// Spreading a string-keyed array supplies named arguments.
$arguments = ['name' => 'Vellin Halt', 'zone' => 4, 'platforms' => 3];
print_r(makeStation(...$arguments));

// A misspelled name is an error, which a positional call could never catch.
try {
    makeStation('Bramble Fields', zoen: 4);
} catch (Error $error) {
    echo 'caught: ', $error->getMessage(), PHP_EOL;
}
