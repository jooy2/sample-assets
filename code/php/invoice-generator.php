<?php

declare(strict_types=1);

/**
 * invoice-generator.php — building, calculating, and rendering an invoice.
 *
 * Enums with backed values and methods, readonly classes and promoted
 * constructor properties, first-class callable syntax, named arguments, the
 * match expression, generators, interfaces with default behaviour through
 * traits, and integer money so nothing is lost to floating point.
 *
 *   php invoice-generator.php
 *   php invoice-generator.php --format=html > invoice.html
 *
 * Requires PHP 8.2 or later. Every company, address, and figure below is
 * invented; this is not a real invoice and must not be used as one.
 */

// ---------------------------------------------------------------- the money

/**
 * An amount in the smallest unit of its currency, so 12.34 GBP is 1234.
 *
 * Storing money as a float is the single most common way to build an invoice
 * that is a penny out, and no amount of rounding at the end repairs it.
 */
final readonly class Money implements JsonSerializable, Stringable
{
    public function __construct(
        public int $minor,
        public Currency $currency = Currency::GBP,
    ) {
    }

    public static function fromMajor(float $amount, Currency $currency = Currency::GBP): self
    {
        return new self((int) round($amount * 100), $currency);
    }

    public static function zero(Currency $currency = Currency::GBP): self
    {
        return new self(0, $currency);
    }

    public function plus(self $other): self
    {
        $this->assertSameCurrency($other);
        return new self($this->minor + $other->minor, $this->currency);
    }

    public function minus(self $other): self
    {
        $this->assertSameCurrency($other);
        return new self($this->minor - $other->minor, $this->currency);
    }

    /** Multiply by a quantity, rounding half up at the end and only once. */
    public function times(float $factor): self
    {
        return new self((int) round($this->minor * $factor), $this->currency);
    }

    /** A percentage of this amount. */
    public function percent(float $rate): self
    {
        return $this->times($rate / 100);
    }

    public function isZero(): bool
    {
        return $this->minor === 0;
    }

    public function isNegative(): bool
    {
        return $this->minor < 0;
    }

    public function compareTo(self $other): int
    {
        $this->assertSameCurrency($other);
        return $this->minor <=> $other->minor;
    }

    /**
     * Split into $parts as evenly as possible, giving the remainder to the
     * earliest parts. The pennies always add back up to the original.
     *
     * @return list<self>
     */
    public function allocate(int $parts): array
    {
        if ($parts < 1) {
            throw new InvalidArgumentException("cannot split money into {$parts} parts");
        }

        $base = intdiv($this->minor, $parts);
        $remainder = $this->minor - ($base * $parts);

        $out = [];
        for ($index = 0; $index < $parts; $index++) {
            $extra = $index < abs($remainder) ? ($remainder <=> 0) : 0;
            $out[] = new self($base + $extra, $this->currency);
        }
        return $out;
    }

    public function format(): string
    {
        $sign = $this->minor < 0 ? '-' : '';
        $absolute = abs($this->minor);
        $major = intdiv($absolute, 100);
        $minor = $absolute % 100;

        return sprintf(
            '%s%s%s.%02d',
            $sign,
            $this->currency->symbol(),
            number_format($major, 0, '.', ','),
            $minor,
        );
    }

    public function __toString(): string
    {
        return $this->format();
    }

    public function jsonSerialize(): array
    {
        return [
            'minor' => $this->minor,
            'currency' => $this->currency->value,
            'formatted' => $this->format(),
        ];
    }

    private function assertSameCurrency(self $other): void
    {
        if ($this->currency !== $other->currency) {
            throw new DomainException(sprintf(
                'cannot combine %s with %s',
                $this->currency->value,
                $other->currency->value,
            ));
        }
    }
}

enum Currency: string
{
    case GBP = 'GBP';
    case EUR = 'EUR';
    case USD = 'USD';

    public function symbol(): string
    {
        return match ($this) {
            Currency::GBP => "\u{00A3}",
            Currency::EUR => "\u{20AC}",
            Currency::USD => '$',
        };
    }
}

// ------------------------------------------------------------------- rates

enum TaxRate: string
{
    case Standard = 'standard';
    case Reduced = 'reduced';
    case Zero = 'zero';
    case Exempt = 'exempt';

    public function percentage(): float
    {
        return match ($this) {
            TaxRate::Standard => 20.0,
            TaxRate::Reduced => 5.0,
            TaxRate::Zero, TaxRate::Exempt => 0.0,
        };
    }

    public function label(): string
    {
        return match ($this) {
            TaxRate::Standard => 'VAT 20%',
            TaxRate::Reduced => 'VAT 5%',
            TaxRate::Zero => 'zero rated',
            TaxRate::Exempt => 'exempt',
        };
    }

    /** Exempt supplies are excluded from the taxable turnover; zero rated are not. */
    public function countsTowardsTurnover(): bool
    {
        return $this !== TaxRate::Exempt;
    }
}

enum InvoiceStatus: string
{
    case Draft = 'draft';
    case Issued = 'issued';
    case PartlyPaid = 'partly-paid';
    case Paid = 'paid';
    case Overdue = 'overdue';
    case Cancelled = 'cancelled';

    public function isFinal(): bool
    {
        return match ($this) {
            InvoiceStatus::Paid, InvoiceStatus::Cancelled => true,
            default => false,
        };
    }
}

// ------------------------------------------------------------------ people

final readonly class Address
{
    /** @param list<string> $lines */
    public function __construct(
        public string $name,
        public array $lines,
        public string $postcode,
        public ?string $vatNumber = null,
    ) {
    }

    /** @return list<string> */
    public function block(): array
    {
        $out = [$this->name, ...$this->lines, $this->postcode];
        if ($this->vatNumber !== null) {
            $out[] = 'VAT ' . $this->vatNumber;
        }
        return $out;
    }
}

// ------------------------------------------------------------------- lines

interface Chargeable
{
    public function description(): string;

    public function net(): Money;

    public function rate(): TaxRate;
}

/** Shared arithmetic for anything chargeable. */
trait ComputesTax
{
    public function tax(): Money
    {
        return $this->net()->percent($this->rate()->percentage());
    }

    public function gross(): Money
    {
        return $this->net()->plus($this->tax());
    }
}

final readonly class LineItem implements Chargeable
{
    use ComputesTax;

    public function __construct(
        public string $sku,
        public string $title,
        public float $quantity,
        public Money $unitPrice,
        public TaxRate $taxRate = TaxRate::Standard,
        public float $discountPercent = 0.0,
    ) {
        if ($quantity <= 0) {
            throw new InvalidArgumentException("{$sku}: quantity must be positive");
        }
        if ($discountPercent < 0 || $discountPercent > 100) {
            throw new InvalidArgumentException("{$sku}: discount must be 0-100%");
        }
        if ($unitPrice->isNegative()) {
            throw new InvalidArgumentException("{$sku}: a unit price cannot be negative");
        }
    }

    public function description(): string
    {
        $suffix = $this->discountPercent > 0
            ? sprintf(' (less %s%%)', rtrim(rtrim(number_format($this->discountPercent, 2), '0'), '.'))
            : '';
        return $this->title . $suffix;
    }

    public function subtotal(): Money
    {
        return $this->unitPrice->times($this->quantity);
    }

    public function discount(): Money
    {
        return $this->subtotal()->percent($this->discountPercent);
    }

    public function net(): Money
    {
        return $this->subtotal()->minus($this->discount());
    }

    public function rate(): TaxRate
    {
        return $this->taxRate;
    }
}

final readonly class Payment
{
    public function __construct(
        public DateTimeImmutable $received,
        public Money $amount,
        public string $method,
        public string $reference,
    ) {
    }
}

// ---------------------------------------------------------------- exceptions

final class InvoiceException extends RuntimeException
{
    /** @param list<string> $problems */
    public function __construct(public readonly array $problems)
    {
        parent::__construct(
            sprintf("%d problem(s):\n  - %s", count($problems), implode("\n  - ", $problems)),
        );
    }
}

// ------------------------------------------------------------------ invoice

final class Invoice
{
    /** @var list<LineItem> */
    private array $lines = [];

    /** @var list<Payment> */
    private array $payments = [];

    public function __construct(
        public readonly string $number,
        public readonly Address $from,
        public readonly Address $to,
        public readonly DateTimeImmutable $issued,
        public readonly int $termDays = 30,
        public readonly Currency $currency = Currency::GBP,
        public readonly ?string $purchaseOrder = null,
        public readonly ?string $notes = null,
    ) {
    }

    public function add(LineItem ...$lines): self
    {
        foreach ($lines as $line) {
            if ($line->unitPrice->currency !== $this->currency) {
                throw new DomainException(sprintf(
                    '%s is priced in %s, but the invoice is in %s',
                    $line->sku,
                    $line->unitPrice->currency->value,
                    $this->currency->value,
                ));
            }
            $this->lines[] = $line;
        }
        return $this;
    }

    public function pay(Payment $payment): self
    {
        $this->payments[] = $payment;
        return $this;
    }

    /** @return list<LineItem> */
    public function lines(): array
    {
        return $this->lines;
    }

    /** @return list<Payment> */
    public function payments(): array
    {
        return $this->payments;
    }

    public function due(): DateTimeImmutable
    {
        return $this->issued->modify("+{$this->termDays} days");
    }

    // ------------------------------------------------------------- totals

    public function net(): Money
    {
        return $this->sum(static fn (LineItem $line): Money => $line->net());
    }

    public function tax(): Money
    {
        return $this->sum(static fn (LineItem $line): Money => $line->tax());
    }

    public function gross(): Money
    {
        return $this->net()->plus($this->tax());
    }

    public function discountTotal(): Money
    {
        return $this->sum(static fn (LineItem $line): Money => $line->discount());
    }

    public function paid(): Money
    {
        return array_reduce(
            $this->payments,
            static fn (Money $carry, Payment $payment): Money => $carry->plus($payment->amount),
            Money::zero($this->currency),
        );
    }

    public function outstanding(): Money
    {
        return $this->gross()->minus($this->paid());
    }

    /** @param callable(LineItem): Money $extract */
    private function sum(callable $extract): Money
    {
        $total = Money::zero($this->currency);
        foreach ($this->lines as $line) {
            $total = $total->plus($extract($line));
        }
        return $total;
    }

    /**
     * Tax grouped by rate, which is what a VAT return actually needs.
     *
     * @return array<string, array{rate: TaxRate, net: Money, tax: Money}>
     */
    public function taxBreakdown(): array
    {
        $groups = [];
        foreach ($this->lines as $line) {
            $key = $line->taxRate->value;
            $groups[$key] ??= [
                'rate' => $line->taxRate,
                'net' => Money::zero($this->currency),
                'tax' => Money::zero($this->currency),
            ];
            $groups[$key]['net'] = $groups[$key]['net']->plus($line->net());
            $groups[$key]['tax'] = $groups[$key]['tax']->plus($line->tax());
        }

        uasort(
            $groups,
            static fn (array $a, array $b): int => $b['rate']->percentage() <=> $a['rate']->percentage(),
        );
        return $groups;
    }

    public function status(DateTimeImmutable $asAt): InvoiceStatus
    {
        $outstanding = $this->outstanding();

        return match (true) {
            $this->lines === [] => InvoiceStatus::Draft,
            $outstanding->minor <= 0 => InvoiceStatus::Paid,
            $this->payments !== [] && $outstanding->minor > 0 => InvoiceStatus::PartlyPaid,
            $asAt > $this->due() => InvoiceStatus::Overdue,
            default => InvoiceStatus::Issued,
        };
    }

    /**
     * Check the invoice before it goes anywhere.
     *
     * @throws InvoiceException
     */
    public function validate(): void
    {
        $problems = [];

        if ($this->lines === []) {
            $problems[] = 'the invoice has no lines';
        }
        if (trim($this->number) === '') {
            $problems[] = 'the invoice has no number';
        }
        if ($this->termDays < 0) {
            $problems[] = 'the payment term is negative';
        }
        if ($this->gross()->isNegative()) {
            $problems[] = 'the total is negative';
        }
        if ($this->paid()->compareTo($this->gross()) > 0) {
            $problems[] = sprintf(
                'payments (%s) exceed the total (%s)',
                $this->paid()->format(),
                $this->gross()->format(),
            );
        }

        $seen = [];
        foreach ($this->lines as $line) {
            if (isset($seen[$line->sku])) {
                $problems[] = "{$line->sku} appears more than once";
            }
            $seen[$line->sku] = true;
        }

        if ($problems !== []) {
            throw new InvoiceException($problems);
        }
    }

    /**
     * Instalments that always add back up to the total.
     *
     * A generator rather than an array, because the caller usually wants to
     * walk them once.
     *
     * @return Generator<int, array{due: DateTimeImmutable, amount: Money}>
     */
    public function instalments(int $count, int $everyDays = 30): Generator
    {
        foreach ($this->outstanding()->allocate($count) as $index => $amount) {
            yield [
                'due' => $this->due()->modify(sprintf('+%d days', $index * $everyDays)),
                'amount' => $amount,
            ];
        }
    }
}

// ---------------------------------------------------------------- rendering

interface Renderer
{
    public function render(Invoice $invoice, DateTimeImmutable $asAt): string;
}

final class TextRenderer implements Renderer
{
    public function __construct(private readonly int $width = 74)
    {
    }

    public function render(Invoice $invoice, DateTimeImmutable $asAt): string
    {
        $out = [];
        $rule = str_repeat('=', $this->width);
        $thin = str_repeat('-', $this->width);

        $out[] = $rule;
        $out[] = $this->centre('INVOICE ' . $invoice->number);
        $out[] = $rule;
        $out[] = '';

        $from = $invoice->from->block();
        $to = $invoice->to->block();
        $rows = max(count($from), count($to));
        for ($index = 0; $index < $rows; $index++) {
            $out[] = sprintf(
                '%-36s %s',
                $from[$index] ?? '',
                $to[$index] ?? '',
            );
        }

        $out[] = '';
        $out[] = sprintf('Issued   %s', $invoice->issued->format('j F Y'));
        $out[] = sprintf('Due      %s (%d days)', $invoice->due()->format('j F Y'), $invoice->termDays);
        if ($invoice->purchaseOrder !== null) {
            $out[] = sprintf('Order    %s', $invoice->purchaseOrder);
        }
        $out[] = sprintf('Status   %s', strtoupper($invoice->status($asAt)->value));
        $out[] = '';

        $out[] = sprintf('%-8s %-30s %7s %11s %11s', 'SKU', 'Description', 'Qty', 'Unit', 'Net');
        $out[] = $thin;

        foreach ($invoice->lines() as $line) {
            $out[] = sprintf(
                '%-8s %-30s %7s %11s %11s',
                $line->sku,
                $this->truncate($line->description(), 30),
                rtrim(rtrim(number_format($line->quantity, 2), '0'), '.'),
                $line->unitPrice->format(),
                $line->net()->format(),
            );
        }

        $out[] = $thin;
        $out[] = $this->total('Subtotal', $invoice->net()->plus($invoice->discountTotal()));
        if (!$invoice->discountTotal()->isZero()) {
            $out[] = $this->total('Discount', $invoice->discountTotal()->times(-1));
        }
        $out[] = $this->total('Net', $invoice->net());

        foreach ($invoice->taxBreakdown() as $group) {
            $out[] = $this->total(
                sprintf('%s on %s', $group['rate']->label(), $group['net']->format()),
                $group['tax'],
            );
        }

        $out[] = $this->total('TOTAL', $invoice->gross());

        if ($invoice->payments() !== []) {
            $out[] = '';
            foreach ($invoice->payments() as $payment) {
                $out[] = $this->total(
                    sprintf('Paid %s, %s', $payment->received->format('j M Y'), $payment->method),
                    $payment->amount->times(-1),
                );
            }
            $out[] = $this->total('OUTSTANDING', $invoice->outstanding());
        }

        if ($invoice->notes !== null) {
            $out[] = '';
            $out[] = wordwrap($invoice->notes, $this->width, "\n", true);
        }

        $out[] = $rule;
        return implode("\n", $out) . "\n";
    }

    private function total(string $label, Money $amount): string
    {
        return sprintf('%' . ($this->width - 13) . 's %12s', $label, $amount->format());
    }

    private function centre(string $text): string
    {
        $pad = max(0, intdiv($this->width - mb_strlen($text), 2));
        return str_repeat(' ', $pad) . $text;
    }

    private function truncate(string $text, int $width): string
    {
        return mb_strlen($text) <= $width
            ? $text
            : mb_substr($text, 0, $width - 1) . "\u{2026}";
    }
}

final class HtmlRenderer implements Renderer
{
    public function render(Invoice $invoice, DateTimeImmutable $asAt): string
    {
        $escape = static fn (string $text): string => htmlspecialchars($text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

        $rows = '';
        foreach ($invoice->lines() as $line) {
            $rows .= sprintf(
                "      <tr><td>%s</td><td>%s</td><td class=\"n\">%s</td>"
                . "<td class=\"n\">%s</td><td class=\"n\">%s</td></tr>\n",
                $escape($line->sku),
                $escape($line->description()),
                $escape((string) $line->quantity),
                $escape($line->unitPrice->format()),
                $escape($line->net()->format()),
            );
        }

        $taxRows = '';
        foreach ($invoice->taxBreakdown() as $group) {
            $taxRows .= sprintf(
                "      <tr><th colspan=\"4\">%s</th><td class=\"n\">%s</td></tr>\n",
                $escape($group['rate']->label()),
                $escape($group['tax']->format()),
            );
        }

        $number = $escape($invoice->number);
        $issued = $invoice->issued->format('j F Y');
        $dueOn = $invoice->due()->format('j F Y');
        $totalText = $escape($invoice->gross()->format());
        $statusText = $escape($invoice->status($asAt)->value);

        // Heredoc interpolation understands $var, $obj->prop and
        // $obj->method(), but not a call through a closure variable, so every
        // value below is worked out first.
        return <<<HTML
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Invoice {$number}</title>
          <style>
            body { font: 14px/1.5 Georgia, serif; margin: 3rem auto; max-width: 44rem; }
            table { border-collapse: collapse; width: 100%; margin-block: 1.5rem; }
            th, td { padding: 0.4rem 0.6rem; border-bottom: 1px solid #ccc; text-align: left; }
            .n { text-align: right; font-variant-numeric: tabular-nums; }
            .total td, .total th { border-top: 2px solid #000; font-weight: 700; }
          </style>
        </head>
        <body>
          <h1>Invoice {$number}</h1>
          <p>Issued {$issued}, due {$dueOn}.</p>
          <table>
            <thead>
              <tr><th>SKU</th><th>Description</th><th class="n">Qty</th>
                  <th class="n">Unit</th><th class="n">Net</th></tr>
            </thead>
            <tbody>
        {$rows}    </tbody>
            <tfoot>
        {$taxRows}      <tr class="total"><th colspan="4">Total</th>
                  <td class="n">{$totalText}</td></tr>
            </tfoot>
          </table>
          <p><small>Status: {$statusText}.
             This document is a sample and is not a real invoice.</small></p>
        </body>
        </html>
        HTML;
    }
}

// -------------------------------------------------------------------- demo

function sampleInvoice(): Invoice
{
    $invoice = new Invoice(
        number: 'NFC-2027-0412',
        from: new Address(
            name: 'Northwind Ferry Cooperative',
            lines: ['Terminal Building', '1 Fenwick Quay'],
            postcode: 'FW1 2AA',
            vatNumber: 'GB000000000',
        ),
        to: new Address(
            name: 'Fenwick District Council',
            lines: ['Finance Office', 'Civic Centre'],
            postcode: 'FW1 1AA',
            vatNumber: 'GB111111111',
        ),
        issued: new DateTimeImmutable('2027-06-30'),
        termDays: 30,
        purchaseOrder: 'PO-2271',
        notes: 'Payment by bank transfer to the account on file. This is a sample '
            . 'document produced for a repository of test assets; it records no real '
            . 'transaction and no real organisation.',
    );

    return $invoice->add(
        new LineItem(
            sku: 'SVC-0101',
            title: 'Harbour Loop service, June',
            quantity: 1,
            unitPrice: Money::fromMajor(18_400.00),
            taxRate: TaxRate::Standard,
        ),
        new LineItem(
            sku: 'SVC-0102',
            title: 'Halloway service, June',
            quantity: 1,
            unitPrice: Money::fromMajor(9_250.00),
            taxRate: TaxRate::Standard,
            discountPercent: 7.5,
        ),
        new LineItem(
            sku: 'SVC-0140',
            title: 'Concessionary fares reimbursement',
            quantity: 1,
            unitPrice: Money::fromMajor(4_182.60),
            taxRate: TaxRate::Exempt,
        ),
        new LineItem(
            sku: 'MTR-0220',
            title: 'Timetable printing, 12,000 copies',
            quantity: 12,
            unitPrice: Money::fromMajor(64.25),
            taxRate: TaxRate::Zero,
        ),
        new LineItem(
            sku: 'MTR-0310',
            title: 'Terminal signage replacement',
            quantity: 6,
            unitPrice: Money::fromMajor(212.40),
            taxRate: TaxRate::Reduced,
        ),
    );
}

function main(array $argv): int
{
    $format = 'text';
    foreach (array_slice($argv, 1) as $argument) {
        if (str_starts_with($argument, '--format=')) {
            $format = substr($argument, 9);
        }
    }

    $asAt = new DateTimeImmutable('2027-09-02');
    $invoice = sampleInvoice();

    if ($format === 'html') {
        echo (new HtmlRenderer())->render($invoice, $asAt), "\n";
        return 0;
    }

    $invoice->validate();
    echo (new TextRenderer())->render($invoice, $asAt);

    echo "\n--- the same invoice, partly paid ---\n";
    $invoice->pay(new Payment(
        received: new DateTimeImmutable('2027-07-28'),
        amount: Money::fromMajor(20_000.00),
        method: 'bank transfer',
        reference: 'FDC-88213',
    ));
    printf(
        "  gross %s, paid %s, outstanding %s, status %s\n",
        $invoice->gross(),
        $invoice->paid(),
        $invoice->outstanding(),
        $invoice->status($asAt)->value,
    );

    echo "\n--- instalments that add back up ---\n";
    $total = Money::zero();
    foreach ($invoice->instalments(count: 3, everyDays: 30) as $index => $instalment) {
        printf(
            "  %d. %s  %s\n",
            $index + 1,
            $instalment['due']->format('j M Y'),
            $instalment['amount'],
        );
        $total = $total->plus($instalment['amount']);
    }
    printf("  sum of instalments: %s (outstanding %s)\n", $total, $invoice->outstanding());

    echo "\n--- allocation never loses a penny ---\n";
    foreach ([3, 7, 11] as $parts) {
        $pieces = Money::fromMajor(100.00)->allocate($parts);
        $sum = array_reduce(
            $pieces,
            static fn (Money $carry, Money $piece): Money => $carry->plus($piece),
            Money::zero(),
        );
        printf(
            "  %s into %2d: %s ... = %s\n",
            Money::fromMajor(100.00),
            $parts,
            implode(' ', array_map(static fn (Money $m): string => $m->format(), array_slice($pieces, 0, 3))),
            $sum,
        );
    }

    echo "\n--- tax breakdown ---\n";
    foreach ($invoice->taxBreakdown() as $group) {
        printf(
            "  %-14s net %11s  tax %10s  %s\n",
            $group['rate']->value,
            $group['net']->format(),
            $group['tax']->format(),
            $group['rate']->countsTowardsTurnover() ? 'in turnover' : 'excluded',
        );
    }

    echo "\n--- what the validator refuses ---\n";
    $attempts = [
        'no lines' => static function (): void {
            (new Invoice(
                number: 'X-1',
                from: new Address('a', [], 'A1'),
                to: new Address('b', [], 'B1'),
                issued: new DateTimeImmutable('2027-01-01'),
            ))->validate();
        },
        'a repeated sku' => static function (): void {
            $bad = new Invoice(
                number: 'X-2',
                from: new Address('a', [], 'A1'),
                to: new Address('b', [], 'B1'),
                issued: new DateTimeImmutable('2027-01-01'),
            );
            $line = new LineItem('DUP-1', 'thing', 1, Money::fromMajor(1.00));
            $bad->add($line, $line)->validate();
        },
        'overpayment' => static function (): void {
            $bad = new Invoice(
                number: 'X-3',
                from: new Address('a', [], 'A1'),
                to: new Address('b', [], 'B1'),
                issued: new DateTimeImmutable('2027-01-01'),
            );
            $bad->add(new LineItem('A-1', 'thing', 1, Money::fromMajor(10.00)))
                ->pay(new Payment(new DateTimeImmutable('2027-02-01'), Money::fromMajor(50.00), 'cash', 'r'))
                ->validate();
        },
    ];

    foreach ($attempts as $label => $attempt) {
        try {
            $attempt();
            printf("  %-16s unexpectedly accepted\n", $label);
        } catch (InvoiceException $error) {
            printf("  %-16s %s\n", $label, implode('; ', $error->problems));
        }
    }

    echo "\n--- constructor guards ---\n";
    $guards = [
        'zero quantity' => static fn (): LineItem => new LineItem('A', 'x', 0, Money::fromMajor(1.00)),
        'negative price' => static fn (): LineItem => new LineItem('B', 'x', 1, new Money(-100)),
        'discount over 100' => static fn (): LineItem => new LineItem('C', 'x', 1, Money::fromMajor(1.00), discountPercent: 150),
        'mixed currency' => static fn (): Money => Money::fromMajor(1.00, Currency::GBP)
            ->plus(Money::fromMajor(1.00, Currency::EUR)),
        'split into zero' => static fn (): array => Money::fromMajor(1.00)->allocate(0),
    ];
    foreach ($guards as $label => $guard) {
        try {
            $guard();
            printf("  %-20s unexpectedly accepted\n", $label);
        } catch (InvalidArgumentException | DomainException $error) {
            printf("  %-20s %s\n", $label, $error->getMessage());
        }
    }

    echo "\n--- json ---\n";
    echo json_encode(
        ['number' => $invoice->number, 'total' => $invoice->gross(), 'outstanding' => $invoice->outstanding()],
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE,
    ), "\n";

    return 0;
}

exit(main($argv ?? []));
