"""Dataclasses: __init__, __repr__, and __eq__ generated from annotations."""

from dataclasses import asdict, dataclass, field, replace
from datetime import date


@dataclass(frozen=True, slots=True)
class Address:
    city: str
    country: str
    postal_code: str

    def __str__(self) -> str:
        return f"{self.city}, {self.country} {self.postal_code}"


@dataclass(order=True)
class Station:
    # sort_index is compared first and hidden from the constructor.
    sort_index: int = field(init=False, repr=False)

    name: str
    line: str
    zone: int = 1
    platforms: int = 2
    step_free: bool = False
    # A mutable default needs a factory, or every instance would share one.
    connections: list[str] = field(default_factory=list)
    opened: date = field(default_factory=lambda: date(1978, 4, 11))

    def __post_init__(self) -> None:
        if not 1 <= self.zone <= 6:
            raise ValueError(f"zone {self.zone} is outside 1-6")
        self.sort_index = self.zone

    @property
    def is_interchange(self) -> bool:
        return len(self.connections) > 1


alder = Station("Alder Cross", "Amber", zone=2, step_free=True, connections=["Amber", "Slate"])
quill = Station("Quill Wharf", "Cobalt", zone=3, platforms=4)

print(alder)
print(f"interchange: {alder.is_interchange}, platforms: {quill.platforms}")

# replace() copies with changes, leaving the original alone.
moved = replace(quill, zone=4, platforms=6)
print(moved)
print("original untouched:", quill.zone)

print("as a dict:", asdict(alder)["connections"])
print("sorted by zone:", [s.name for s in sorted([quill, alder])])

# A frozen dataclass is hashable, so it works as a dict key or in a set.
home = Address("Harrowgate", "Kestrand", "KE-8256")
same = Address("Harrowgate", "Kestrand", "KE-8256")
print(home, "| equal:", home == same, "| one in a set:", len({home, same}))

try:
    home.city = "Elsewhere"  # type: ignore[misc]
except AttributeError as error:
    print("frozen:", error)

try:
    Station("Far Halt", "Slate", zone=9)
except ValueError as error:
    print("rejected:", error)
