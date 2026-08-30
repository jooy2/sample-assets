"""Annotations: generics, unions, protocols, and the typing constructs a
checker uses. They do not change how the code runs."""

from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from typing import Any, Literal, NamedTuple, Optional, Protocol, TypeAlias, TypedDict, cast

Zone: TypeAlias = int
Line = Literal["Amber", "Cobalt", "Emerald", "Crimson", "Slate"]


class StationDict(TypedDict):
    """A dict with a fixed set of keys and a type for each."""

    name: str
    line: Line
    zone: Zone
    step_free: bool


class GridPoint(NamedTuple):
    x: int
    y: int

    def shifted(self, dx: int = 0, dy: int = 0) -> "GridPoint":
        return GridPoint(self.x + dx, self.y + dy)


@dataclass
class Station:
    name: str
    line: Line
    zone: Zone
    location: GridPoint
    nickname: str | None = None  # the modern spelling of Optional[str]


class Measurable(Protocol):
    """Structural typing: anything with this method fits, with no base class."""

    def area(self) -> float: ...


@dataclass
class Rectangle:
    width: float
    height: float

    def area(self) -> float:
        return self.width * self.height


def total_area(shapes: Iterable[Measurable]) -> float:
    return sum(shape.area() for shape in shapes)


# A generic function, in the 3.12 syntax.
def first[T](values: Sequence[T], fallback: T) -> T:
    return values[0] if values else fallback


def largest_by[T, K](values: Iterable[T], key: Callable[[T], K]) -> T:
    return max(values, key=key)  # type: ignore[arg-type,return-value]


def label(station: Station) -> str:
    # A narrowing check tells the checker the value is no longer None.
    if station.nickname is not None:
        return station.nickname
    return station.name


def describe(value: int | str | None) -> str:
    match value:
        case None:
            return "nothing"
        case int() as number if number > 10:
            return f"a large int, {number}"
        case int():
            return "a small int"
        case str() as text:
            return f"a string of {len(text)} characters"


stations = [
    Station("Alder Cross", "Amber", 2, GridPoint(45, -10), nickname="the Cross"),
    Station("Quill Wharf", "Cobalt", 3, GridPoint(12, 8)),
]

for station in stations:
    print(f"{label(station):<12} {station.line:<8} {station.location.shifted(dy=5)}")

print("total area:", total_area([Rectangle(4, 4), Rectangle(3, 6)]))
print("first:", first([], "fallback"), "|", first(["Amber", "Cobalt"], "fallback"))
print("deepest:", largest_by(stations, lambda s: s.zone).name)

for value in (42, 3, "amber", None):
    print(f"  {value!r:<8} -> {describe(value)}")

payload: StationDict = {"name": "Nether Gate", "line": "Emerald", "zone": 2, "step_free": True}
print("typed dict:", payload["name"], payload["zone"])

# cast() only tells the checker; nothing is converted at runtime.
raw: Any = {"name": "Saltwick Halt", "line": "Amber", "zone": 5, "step_free": True}
checked = cast(StationDict, raw)
print("cast:", checked["line"], "| Optional is still", Optional[int])

print("annotations are data:", describe.__annotations__["return"])
