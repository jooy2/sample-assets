<?php

declare(strict_types=1);

// Closures, arrow functions, `use` by value and by reference, and the
// several shapes a callable can take.

$base = 2.40;

// A classic closure has to import what it captures.
$fare = function (int $zones) use ($base): float {
    return $base + $zones * 0.85;
};

// An arrow function captures the enclosing scope automatically, by value.
$shortFare = fn (int $zones): float => $base + $zones * 0.85;

printf("three zones: %.2f / %.2f%s", $fare(3), $shortFare(3), PHP_EOL);

// `use (&$x)` shares the variable rather than copying it.
$calls = 0;
$counted = function () use (&$calls): int {
    return ++$calls;
};
$counted();
$counted();
echo "called {$calls} times", PHP_EOL;

// A closure factory keeps its captured state alive.
function makeCounter(int $start = 0): callable
{
    $value = $start;
    return function () use (&$value): int {
        return $value++;
    };
}
$ticket = makeCounter(1000);
echo $ticket(), ' ', $ticket(), ' ', $ticket(), PHP_EOL;

// Closures can be bound to an object, which gives them $this.
class Basket
{
    private array $items = ['mug', 'skillet'];
}

$peek = function (): array {
    return $this->items;
};
$bound = Closure::bind($peek, new Basket(), Basket::class);
echo 'bound closure sees: ', implode(', ', $bound()), PHP_EOL;

// The four callable syntaxes.
$stations = ['Alder Cross', 'quill wharf', 'SALTWICK HALT'];

echo implode(', ', array_map('ucwords', array_map('strtolower', $stations))), PHP_EOL;
echo implode(', ', array_map(fn (string $s): int => strlen($s), $stations)), PHP_EOL;

final class Formatter
{
    public static function slug(string $text): string
    {
        return strtolower(str_replace(' ', '-', trim($text)));
    }

    public function shout(string $text): string
    {
        return strtoupper($text);
    }
}

echo implode(', ', array_map([Formatter::class, 'slug'], $stations)), PHP_EOL;
echo implode(', ', array_map([new Formatter(), 'shout'], $stations)), PHP_EOL;
echo implode(', ', array_map(Formatter::slug(...), $stations)), PHP_EOL; // first-class callable

// A callable stored in a property needs parentheses to be called.
final class Pipeline
{
    /** @var list<callable> */
    private array $steps = [];

    public function add(callable $step): static
    {
        $this->steps[] = $step;
        return $this;
    }

    public function run(mixed $value): mixed
    {
        foreach ($this->steps as $step) {
            $value = $step($value);
        }
        return $value;
    }
}

echo (new Pipeline())
    ->add(trim(...))
    ->add(strtolower(...))
    ->add(fn (string $s): string => str_replace(' ', '-', $s))
    ->run('  Alder Cross  '), PHP_EOL;
