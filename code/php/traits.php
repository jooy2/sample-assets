<?php

declare(strict_types=1);

// A trait is a bundle of methods and properties that several unrelated
// classes can pull in, without a shared base class.

trait Timestamps
{
    private ?string $createdAt = null;
    private ?string $updatedAt = null;

    public function touch(): static
    {
        $now = '2025-11-10T09:15:00Z';
        $this->createdAt ??= $now;
        $this->updatedAt = $now;
        return $this;
    }

    public function age(): string
    {
        return $this->createdAt === null ? 'never saved' : "created {$this->createdAt}";
    }
}

trait Loggable
{
    /** @var list<string> */
    private array $log = [];

    public function record(string $message): void
    {
        $this->log[] = sprintf('[%s] %s', static::class, $message);
    }

    /** @return list<string> */
    public function history(): array
    {
        return $this->log;
    }
}

trait Greets
{
    public function hello(): string
    {
        return 'hello from Greets';
    }
}

trait Waves
{
    public function hello(): string
    {
        return 'hello from Waves';
    }
}

final class Station
{
    use Timestamps;
    use Loggable;

    // When two traits collide, the class says which one wins and can
    // rename the other.
    use Greets, Waves {
        Greets::hello insteadof Waves;
        Waves::hello as wave;
    }

    public function __construct(public readonly string $name)
    {
        $this->record("created {$name}");
    }
}

$station = (new Station('Alder Cross'))->touch();
$station->record('platform 2 closed');

echo $station->name, ': ', $station->age(), PHP_EOL;
echo implode(PHP_EOL, $station->history()), PHP_EOL;
echo $station->hello(), PHP_EOL;
echo $station->wave(), PHP_EOL;

echo 'traits used: ', implode(', ', class_uses($station)), PHP_EOL;
