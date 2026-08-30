<?php

declare(strict_types=1);

// Throwing, catching by type, chaining a previous exception, and finally.

final class ValidationException extends RuntimeException
{
    public function __construct(
        public readonly string $field,
        string $message,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }
}

final class OutOfRangeZoneException extends ValidationException
{
}

function parseZone(string $raw): int
{
    if (!ctype_digit($raw)) {
        // Wrap the low-level failure so the caller has one type to catch.
        $cause = new InvalidArgumentException("\"{$raw}\" is not a number");
        throw new ValidationException('zone', "cannot read a zone from \"{$raw}\"", $cause);
    }

    $zone = (int) $raw;
    if ($zone < 1 || $zone > 6) {
        throw new OutOfRangeZoneException('zone', "zone {$zone} is outside 1-6");
    }
    return $zone;
}

foreach (['3', '9', 'east'] as $raw) {
    try {
        printf("%-6s -> zone %d%s", $raw, parseZone($raw), PHP_EOL);
    } catch (OutOfRangeZoneException $error) {
        // The most specific catch block wins, so order matters.
        printf("%-6s -> out of range: %s%s", $raw, $error->getMessage(), PHP_EOL);
    } catch (ValidationException $error) {
        $because = $error->getPrevious()?->getMessage() ?? 'no cause recorded';
        printf("%-6s -> %s (%s)%s", $raw, $error->getMessage(), $because, PHP_EOL);
    }
}

// Several types in one catch.
try {
    throw new TypeError('the wrong type arrived');
} catch (TypeError | ValueError $error) {
    echo 'caught a ', $error::class, PHP_EOL;
}

// A catch block does not have to name the variable.
try {
    throw new LogicException('ignored');
} catch (LogicException) {
    echo 'caught, without binding it', PHP_EOL;
}

// finally runs even when the try block returns.
function withCleanup(): string
{
    $open = ['report.csv'];
    try {
        return 'returned from the try block';
    } finally {
        $open = [];
        echo 'cleaned up, ', count($open), ' handles left open', PHP_EOL;
    }
}
echo withCleanup(), PHP_EOL;

// Errors and exceptions share the Throwable interface.
try {
    intdiv(1, 0);
} catch (Throwable $error) {
    echo 'caught a ', $error::class, ': ', $error->getMessage(), PHP_EOL;
}

echo 'trace depth: ', count((new ValidationException('zone', 'x'))->getTrace()), PHP_EOL;
