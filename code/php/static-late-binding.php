<?php

declare(strict_types=1);

// `self` is fixed where it is written; `static` follows the class the call
// actually started from. That difference is late static binding.

abstract class Model
{
    protected static array $store = [];

    public function __construct(public readonly int $id, public readonly string $name)
    {
    }

    /** `new self(...)` would always build a Model; `new static(...)` builds the subclass. */
    public static function create(int $id, string $name): static
    {
        $instance = new static($id, $name);
        static::$store[static::class][] = $instance;
        return $instance;
    }

    public static function table(): string
    {
        return strtolower(static::class) . 's';
    }

    /** self:: is resolved here, in Model, whatever the caller is. */
    public static function tableViaSelf(): string
    {
        return strtolower(self::class) . 's';
    }

    public static function count(): int
    {
        return count(static::$store[static::class] ?? []);
    }
}

final class Station extends Model
{
    public function label(): string
    {
        return "#{$this->id} {$this->name}";
    }
}

final class Product extends Model
{
}

$alder = Station::create(1, 'Alder Cross');
$quill = Station::create(2, 'Quill Wharf');
$mug = Product::create(1, 'Matte Ceramic Mug');

echo 'created a ', $alder::class, ': ', $alder->label(), PHP_EOL;
echo 'created a ', $mug::class, PHP_EOL;

echo 'Station::table() -> ', Station::table(), PHP_EOL;
echo 'Product::table() -> ', Product::table(), PHP_EOL;
echo 'Station::tableViaSelf() -> ', Station::tableViaSelf(), ' (self stayed in Model)', PHP_EOL;

echo 'stations stored: ', Station::count(), PHP_EOL;
echo 'products stored: ', Product::count(), PHP_EOL;

// static also works as a return type, so a fluent chain keeps the subtype.
class QueryBuilder
{
    private array $parts = [];

    public function where(string $clause): static
    {
        $this->parts[] = "WHERE {$clause}";
        return $this;
    }

    public function toSql(): string
    {
        return 'SELECT *' . ($this->parts === [] ? '' : ' ' . implode(' AND ', $this->parts));
    }
}

final class StationQuery extends QueryBuilder
{
    public function inZone(int $zone): static
    {
        return $this->where("zone = {$zone}");
    }
}

echo (new StationQuery())->inZone(2)->where("line = 'Amber'")->toSql(), PHP_EOL;

// Static properties are shared by the class, not by each object.
final class Counter
{
    public static int $made = 0;

    public function __construct()
    {
        self::$made++;
    }
}

new Counter();
new Counter();
echo 'counter made ', Counter::$made, PHP_EOL;
