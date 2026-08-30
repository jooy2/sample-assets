"""Classes: properties, dunder methods, inheritance, and structural typing
with Protocol."""

from abc import ABC, abstractmethod
from collections.abc import Iterator
from typing import Protocol, runtime_checkable


class Vehicle(ABC):
    """An abstract base class cannot be instantiated on its own."""

    def __init__(self, name: str, capacity: int) -> None:
        self.name = name
        self._capacity = capacity

    @property
    def capacity(self) -> int:
        return self._capacity

    @capacity.setter
    def capacity(self, value: int) -> None:
        if value <= 0:
            raise ValueError("capacity must be positive")
        self._capacity = value

    @abstractmethod
    def describe(self) -> str: ...

    def __repr__(self) -> str:
        return f"{type(self).__name__}({self.name!r}, {self._capacity})"

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Vehicle) and (self.name, self._capacity) == (other.name, other._capacity)

    def __hash__(self) -> int:
        return hash((type(self).__name__, self.name, self._capacity))


class Tram(Vehicle):
    def __init__(self, name: str, capacity: int, line: str) -> None:
        super().__init__(name, capacity)
        self.line = line
        self._charge = 100

    def drain(self, amount: int) -> "Tram":
        self._charge = max(0, self._charge - amount)
        return self

    def describe(self) -> str:
        return f"{self.name} on the {self.line} line, {self._charge}% charged"


@runtime_checkable
class Measurable(Protocol):
    """Structural typing: anything with area() fits, with no inheritance."""

    def area(self) -> float: ...


class Rectangle:
    def __init__(self, width: float, height: float) -> None:
        self.width = width
        self.height = height

    def area(self) -> float:
        return self.width * self.height


class Route:
    """The dunder methods that make a class behave like a container."""

    def __init__(self, *stops: str) -> None:
        self._stops = list(stops)

    def __len__(self) -> int:
        return len(self._stops)

    def __getitem__(self, index: int) -> str:
        return self._stops[index]

    def __iter__(self) -> Iterator[str]:
        return iter(self._stops)

    def __contains__(self, stop: object) -> bool:
        return stop in self._stops

    def __add__(self, other: "Route") -> "Route":
        return Route(*self._stops, *other._stops)

    def __str__(self) -> str:
        return " -> ".join(self._stops)


tram = Tram("Tram 14", 180, "Amber").drain(35)
print(tram.describe())
print(repr(tram), "| capacity:", tram.capacity)

tram.capacity = 200
print("after the setter:", tram.capacity)
try:
    tram.capacity = 0
except ValueError as error:
    print("rejected:", error)

try:
    Vehicle("Generic", 10)  # type: ignore[abstract]
except TypeError as error:
    print("abstract:", error)

print("equal:", Tram("Tram 14", 200, "Amber") == tram)
print("in a set:", len({tram, Tram("Tram 14", 200, "Amber")}))

print("Rectangle satisfies Measurable:", isinstance(Rectangle(2, 3), Measurable))
print("total area:", sum(s.area() for s in [Rectangle(4, 4), Rectangle(3, 6)]))

route = Route("Alder Cross", "Quill Wharf") + Route("Saltwick Halt")
print(route, "| stops:", len(route), "| first:", route[0])
print("Quill Wharf is on it:", "Quill Wharf" in route)
print("as a list:", list(route))

print("method resolution order:", [c.__name__ for c in Tram.__mro__])
