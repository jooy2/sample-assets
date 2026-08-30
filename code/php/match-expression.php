<?php

declare(strict_types=1);

// match returns a value, compares strictly, and throws when nothing matches
// — all the places switch does the opposite.

function responseTime(string $priority): string
{
    return match ($priority) {
        'low' => 'within a week',
        'normal' => 'within two days',
        'high' => 'within four hours',
        'urgent' => 'immediately',
        default => 'unclassified',
    };
}

function platformsFor(string $line): int
{
    return match ($line) {
        'Amber', 'Cobalt' => 4,       // several values share one arm
        'Emerald', 'Crimson' => 3,
        'Slate' => 2,
        default => 1,
    };
}

/** Without a subject, match is a tidy chain of conditions. */
function describeZone(int $zone): string
{
    return match (true) {
        $zone < 1, $zone > 6 => 'off the network',
        $zone <= 2 => 'central',
        $zone <= 4 => 'suburban',
        default => 'outer',
    };
}

foreach (['low', 'urgent', 'whenever'] as $priority) {
    printf("%-9s %s%s", $priority, responseTime($priority), PHP_EOL);
}

foreach (['Amber', 'Slate', 'Violet'] as $line) {
    echo $line, ' -> ', platformsFor($line), ' platforms', PHP_EOL;
}

foreach ([1, 3, 5, 9] as $zone) {
    echo "zone {$zone} is ", describeZone($zone), PHP_EOL;
}

// match compares with ===, so no juggling. switch would have matched here.
$value = '1';
echo 'match: ', match (true) {
    $value === 1 => 'the integer one',
    $value === '1' => 'the string one',
}, PHP_EOL;

switch ($value) {
    case 1:
        echo 'switch: the integer one (loose comparison)', PHP_EOL;
        break;
    default:
        echo 'switch: something else', PHP_EOL;
}

// Without a default, an unmatched subject is an error rather than silence.
try {
    echo match ('violet') {
        'amber' => 'known',
    };
} catch (\UnhandledMatchError $error) {
    echo 'caught: ', $error->getMessage(), PHP_EOL;
}

// Each arm is a single expression, so side effects belong in a function.
$log = [];
$outcome = match (true) {
    default => (function () use (&$log): string {
        $log[] = 'evaluated';
        return 'computed in a closure';
    })(),
};
echo $outcome, ' / log: ', implode(',', $log), PHP_EOL;
