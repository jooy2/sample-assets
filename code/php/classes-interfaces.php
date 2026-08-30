<?php

declare(strict_types=1);

// Classes, interfaces, abstract classes, and constructor property promotion.

interface Payable
{
    public function monthlyPay(): float;
}

interface Describable
{
    public function describe(): string;
}

abstract class Employee implements Payable, Describable
{
    // Constructor property promotion declares and assigns in one place.
    public function __construct(
        protected readonly string $name,
        protected readonly string $department,
        private float $baseSalary,
    ) {
    }

    public function monthlyPay(): float
    {
        return $this->baseSalary / 12;
    }

    public function describe(): string
    {
        return sprintf('%s (%s) earns %.2f a month', $this->name, $this->department, $this->monthlyPay());
    }

    /** Each concrete employee decides its own title. */
    abstract public function title(): string;

    protected function baseSalary(): float
    {
        return $this->baseSalary;
    }
}

final class Engineer extends Employee
{
    public function __construct(string $name, float $base, private float $bonus)
    {
        parent::__construct($name, 'Engineering', $base);
    }

    public function title(): string
    {
        return 'Engineer';
    }

    public function monthlyPay(): float
    {
        return parent::monthlyPay() + $this->bonus / 12;
    }
}

final class Contractor extends Employee
{
    public function __construct(string $name, private float $rate, private int $hours)
    {
        parent::__construct($name, 'Logistics', 0.0);
    }

    public function title(): string
    {
        return 'Contractor';
    }

    public function monthlyPay(): float
    {
        return $this->rate * $this->hours;
    }
}

$staff = [
    new Engineer('Yolanda Blackwood', 132_000, 18_000),
    new Contractor('Talia Whitlock', 85.0, 120),
];

$payroll = 0.0;
foreach ($staff as $person) {
    printf("%-12s %s%s", $person->title(), $person->describe(), PHP_EOL);
    $payroll += $person->monthlyPay();
}
printf('monthly payroll %.2f%s', $payroll, PHP_EOL);

echo 'Engineer is Payable: ', var_export($staff[0] instanceof Payable, true), PHP_EOL;
echo 'implements: ', implode(', ', class_implements($staff[0])), PHP_EOL;
