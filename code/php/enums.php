<?php

declare(strict_types=1);

// PHP 8.1 enums: pure cases, backed cases, and the methods and interfaces
// they can carry.

enum Priority
{
    case Low;
    case Normal;
    case High;
    case Urgent;

    public function responseTime(): string
    {
        return match ($this) {
            Priority::Low => 'within a week',
            Priority::Normal => 'within two days',
            Priority::High => 'within four hours',
            Priority::Urgent => 'immediately',
        };
    }
}

interface HasColour
{
    public function colour(): string;
}

/** A backed enum has a scalar value behind each case. */
enum TransitLine: string implements HasColour
{
    case Amber = 'amber';
    case Cobalt = 'cobalt';
    case Emerald = 'emerald';
    case Crimson = 'crimson';

    // Constants and static methods are allowed; properties are not.
    public const DEFAULT = self::Amber;

    public function colour(): string
    {
        return match ($this) {
            self::Amber => '#c8a02a',
            self::Cobalt => '#2a5cc8',
            self::Emerald => '#2ac86b',
            self::Crimson => '#c82a3c',
        };
    }

    public function label(): string
    {
        return ucfirst($this->value) . ' line';
    }

    public static function accessible(): array
    {
        return [self::Amber, self::Emerald, self::Crimson];
    }
}

foreach (Priority::cases() as $priority) {
    printf("%-7s %s%s", $priority->name, $priority->responseTime(), PHP_EOL);
}

echo PHP_EOL;
foreach (TransitLine::cases() as $line) {
    printf("%-10s %-8s %s%s", $line->name, $line->value, $line->colour(), PHP_EOL);
}

// from() throws on an unknown value; tryFrom() returns null.
echo 'from("cobalt"): ', TransitLine::from('cobalt')->label(), PHP_EOL;
echo 'tryFrom("violet"): ', var_export(TransitLine::tryFrom('violet'), true), PHP_EOL;

try {
    TransitLine::from('violet');
} catch (ValueError $error) {
    echo 'from() threw: ', $error->getMessage(), PHP_EOL;
}

echo 'default: ', TransitLine::DEFAULT->label(), PHP_EOL;
echo 'accessible: ', implode(', ', array_column(TransitLine::accessible(), 'value')), PHP_EOL;

// Enum cases are singletons, so identity comparison works.
$line = TransitLine::Amber;
echo 'identical: ', var_export($line === TransitLine::from('amber'), true), PHP_EOL;
echo 'is a HasColour: ', var_export($line instanceof HasColour, true), PHP_EOL;

// Backed enums serialise to their value.
echo json_encode(['line' => TransitLine::Emerald, 'priority' => Priority::High->name]), PHP_EOL;
