<?php

declare(strict_types=1);

// json_encode and json_decode, with the flags and error handling that
// production code needs.

final class Order implements JsonSerializable
{
    public function __construct(
        public readonly string $orderId,
        public readonly int $userId,
        public readonly float $total,
        public readonly string $status,
        public readonly ?string $shippedAt = null,
    ) {
    }

    public static function fromArray(array $data): self
    {
        return new self(
            orderId: $data['order_id'],
            userId: $data['user_id'],
            total: (float) $data['total'],
            status: $data['status'],
            shippedAt: $data['shipped_at'] ?? null,
        );
    }

    /** Decides the shape this object takes in JSON. */
    public function jsonSerialize(): array
    {
        return array_filter([
            'order_id' => $this->orderId,
            'user_id' => $this->userId,
            'total' => $this->total,
            'status' => $this->status,
            'shipped_at' => $this->shippedAt,
        ], static fn (mixed $value): bool => $value !== null);
    }
}

$orders = [
    new Order('ORD-10001', 82, 104.35, 'delivered', '2025-11-03T09:15:00Z'),
    new Order('ORD-10002', 6, 42.99, 'pending'),
];

$json = json_encode($orders, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
echo $json, PHP_EOL;

// Decoding to an associative array rather than to stdClass.
$decoded = json_decode($json, associative: true, flags: JSON_THROW_ON_ERROR);
$rebuilt = array_map(Order::fromArray(...), $decoded);

printf("%sdecoded %d orders, first is %s%s", PHP_EOL, count($rebuilt), $rebuilt[0]->orderId, PHP_EOL);
printf("total %.2f%s", array_sum(array_column($decoded, 'total')), PHP_EOL);

// Decoding to objects instead.
$asObjects = json_decode($json, flags: JSON_THROW_ON_ERROR);
echo 'as an object: ', $asObjects[0]->order_id, PHP_EOL;

// Large integers lose precision as floats unless they are kept as strings.
echo json_encode(json_decode('{"id": 12345678901234567890}', true, flags: JSON_BIGINT_AS_STRING)), PHP_EOL;

// Errors are exceptions with JSON_THROW_ON_ERROR, and silent without it.
try {
    json_decode('{"unterminated": ', flags: JSON_THROW_ON_ERROR);
} catch (JsonException $error) {
    echo 'caught: ', $error->getMessage(), PHP_EOL;
}

var_dump(json_decode('{"unterminated": '));
echo 'last error: ', json_last_error_msg(), PHP_EOL;

// Unicode and slashes are escaped unless told otherwise.
echo json_encode(['path' => '/api/v1', 'note' => 'café']), PHP_EOL;
echo json_encode(['path' => '/api/v1'], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), PHP_EOL;
