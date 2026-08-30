<?php

declare(strict_types=1);

// DateTimeImmutable, intervals, time zones, and the formatting that goes
// with them.

$opened = new DateTimeImmutable('1978-04-11 09:30:00', new DateTimeZone('UTC'));

echo 'ISO 8601: ', $opened->format(DateTimeInterface::ATOM), PHP_EOL;
echo 'readable: ', $opened->format('l, j F Y \a\t H:i'), PHP_EOL;
echo 'date only: ', $opened->format('Y-m-d'), PHP_EOL;
echo 'timestamp: ', $opened->getTimestamp(), PHP_EOL;

// Immutable: every change returns a new object.
$refurbished = $opened->modify('+45 years')->setTime(6, 0);
echo 'refurbished: ', $refurbished->format('Y-m-d H:i'), PHP_EOL;
echo 'the original is still ', $opened->format('Y-m-d'), PHP_EOL;

// Intervals: adding, subtracting, and measuring.
$oneYearSix = new DateInterval('P1Y6M');
echo 'plus 1y6m: ', $opened->add($oneYearSix)->format('Y-m-d'), PHP_EOL;
echo 'minus 90 days: ', $opened->sub(new DateInterval('P90D'))->format('Y-m-d'), PHP_EOL;

$difference = $opened->diff($refurbished);
printf("between them: %d years, %d months, %d days (%d total)%s",
    $difference->y, $difference->m, $difference->d, $difference->days, PHP_EOL);

// Time zones change the wall clock, not the instant.
$utc = new DateTimeImmutable('2025-11-03 09:15:00', new DateTimeZone('UTC'));
foreach (['UTC', 'Europe/Lisbon', 'Asia/Seoul', 'America/Chicago'] as $zone) {
    $local = $utc->setTimezone(new DateTimeZone($zone));
    printf("%-18s %s (%s)%s", $zone, $local->format('Y-m-d H:i'), $local->format('P'), PHP_EOL);
}

// Parsing a format that is not ISO.
$parsed = DateTimeImmutable::createFromFormat('d/M/Y:H:i:s P', '10/Nov/2025:00:02:25 +0000');
echo 'parsed a log timestamp: ', $parsed->format(DateTimeInterface::ATOM), PHP_EOL;

$bad = DateTimeImmutable::createFromFormat('Y-m-d', '2025-13-45');
echo 'invalid date: ', var_export(DateTimeImmutable::getLastErrors() !== false, true), PHP_EOL;

// Relative formats do a lot of work.
foreach (['tomorrow', 'next monday', 'first day of next month', '-2 weeks'] as $relative) {
    echo str_pad($relative, 26), (new DateTimeImmutable($relative, new DateTimeZone('UTC')))
        ->format('Y-m-d'), PHP_EOL;
}

// A period walks a range in fixed steps.
$period = new DatePeriod(
    new DateTimeImmutable('2025-11-03'),
    new DateInterval('P1W'),
    new DateTimeImmutable('2025-12-01')
);
$weeks = [];
foreach ($period as $week) {
    $weeks[] = $week->format('m-d');
}
echo 'weekly: ', implode(', ', $weeks), PHP_EOL;

echo 'comparison: ', var_export($opened < $refurbished, true), PHP_EOL;
