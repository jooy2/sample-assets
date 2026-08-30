<?php

declare(strict_types=1);

// readonly properties can be written once, from inside the class, and never
// again. A readonly class makes every property readonly at once.

final class Address
{
    public function __construct(
        public readonly string $city,
        public readonly string $country,
        public readonly string $postalCode,
    ) {
    }

    /** Changing a readonly value means building a new object. */
    public function withCity(string $city): self
    {
        return new self($city, $this->country, $this->postalCode);
    }

    public function __toString(): string
    {
        return "{$this->city}, {$this->country} {$this->postalCode}";
    }
}

// PHP 8.2: every declared property is readonly.
final readonly class Money
{
    public function __construct(
        public int $cents,
        public string $currency = 'USD',
    ) {
        if ($cents < 0) {
            throw new InvalidArgumentException('cents cannot be negative');
        }
    }

    public function plus(Money $other): self
    {
        if ($other->currency !== $this->currency) {
            throw new InvalidArgumentException('currencies must match');
        }
        return new self($this->cents + $other->cents, $this->currency);
    }

    public function __toString(): string
    {
        return sprintf('%.2f %s', $this->cents / 100, $this->currency);
    }
}

$address = new Address('Harrowgate', 'Kestrand', 'KE-8256');
echo $address, PHP_EOL;

$moved = $address->withCity('Stonebay');
echo $moved, ' (the original is still ', $address->city, ')', PHP_EOL;

try {
    $address->city = 'Elsewhere';
} catch (Error $error) {
    echo 'rejected: ', $error->getMessage(), PHP_EOL;
}

$subtotal = new Money(7450);
$shipping = new Money(499);
echo 'total ', $subtotal->plus($shipping), PHP_EOL;

try {
    $subtotal->plus(new Money(100, 'EUR'));
} catch (InvalidArgumentException $error) {
    echo 'rejected: ', $error->getMessage(), PHP_EOL;
}

try {
    new Money(-1);
} catch (InvalidArgumentException $error) {
    echo 'rejected: ', $error->getMessage(), PHP_EOL;
}

// A readonly property holding an object still protects only the reference:
// the object it points at can change unless it is readonly too.
final class Basket
{
    /** @param list<string> $items */
    public function __construct(public readonly array $items)
    {
    }
}

$basket = new Basket(['mug', 'skillet']);
echo 'items: ', implode(', ', $basket->items), PHP_EOL;

try {
    $basket->items[] = 'kettle';
} catch (Error $error) {
    echo 'arrays are values, so this fails too: ', $error->getMessage(), PHP_EOL;
}
