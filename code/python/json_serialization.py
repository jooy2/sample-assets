"""Reading and writing JSON, including the hooks for types json does not
know about."""

import json
from dataclasses import dataclass, asdict
from datetime import date, datetime, timezone
from decimal import Decimal


@dataclass
class Order:
    order_id: str
    user_id: int
    total: Decimal
    status: str
    shipped_at: datetime | None = None


class OrderEncoder(json.JSONEncoder):
    """Called for any object json cannot serialise on its own."""

    def default(self, o: object) -> object:
        if isinstance(o, datetime):
            return o.isoformat().replace("+00:00", "Z")
        if isinstance(o, date):
            return o.isoformat()
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


def order_hook(payload: dict) -> dict:
    """Called for every object on the way in, innermost first."""
    if "shipped_at" in payload and isinstance(payload["shipped_at"], str):
        payload["shipped_at"] = datetime.fromisoformat(payload["shipped_at"].replace("Z", "+00:00"))
    if "total" in payload:
        payload["total"] = Decimal(str(payload["total"]))
    return payload


orders = [
    Order("ORD-10001", 82, Decimal("104.35"), "delivered",
          datetime(2025, 11, 3, 9, 15, tzinfo=timezone.utc)),
    Order("ORD-10002", 6, Decimal("42.99"), "pending"),
]

text = json.dumps([asdict(order) for order in orders], cls=OrderEncoder, indent=2)
print(text)

decoded = json.loads(text, object_hook=order_hook)
print("\nshipped_at is a datetime again:", isinstance(decoded[0]["shipped_at"], datetime))
print("total is a Decimal:", decoded[0]["total"], type(decoded[0]["total"]).__name__)
print("sum:", sum(order["total"] for order in decoded))

# Sorting keys and dropping whitespace makes the output stable and compact.
print(json.dumps({"b": 2, "a": 1}, sort_keys=True, separators=(",", ":")))

# Non-ASCII is escaped unless told otherwise.
print(json.dumps({"city": "Bragança"}))
print(json.dumps({"city": "Bragança"}, ensure_ascii=False))

# JSON Lines: one object per line, so a huge file streams.
lines = "\n".join(
    json.dumps({"reading_id": index, "celsius": 20 + index / 10})
    for index in range(1, 4)
)
print("\njsonl:")
for line in lines.splitlines():
    record = json.loads(line)
    print(f"  {record['reading_id']}: {record['celsius']}C")

# Errors carry the position, which is what makes them useful.
try:
    json.loads('{"unterminated": ')
except json.JSONDecodeError as error:
    print(f"\ncaught at line {error.lineno} column {error.colno}: {error.msg}")

# What Python types survive a round trip, and what they turn into.
original = {"tuple": (1, 2), "set_as_list": [1, 2], "none": None, "float": 1.0}
print("round trip:", json.loads(json.dumps(original)))
