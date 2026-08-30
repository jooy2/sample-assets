"""Generators produce values on demand, so a sequence can be endless."""

from collections.abc import Iterable, Iterator
from itertools import islice


def fibonacci() -> Iterator[int]:
    previous, current = 0, 1
    while True:
        yield current
        previous, current = current, previous + current


def traced(source: Iterable[int], log: list[int]) -> Iterator[int]:
    for value in source:
        log.append(value)
        yield value


def read_paragraphs(text: str) -> Iterator[str]:
    """Groups lines into paragraphs without holding the whole text twice."""
    block: list[str] = []
    for line in text.splitlines():
        if line.strip():
            block.append(line.strip())
        elif block:
            yield " ".join(block)
            block = []
    if block:
        yield " ".join(block)


print(list(islice(fibonacci(), 12)))

log: list[int] = []
first_three = list(islice((n for n in traced(range(1, 1000), log) if n % 7 == 0), 3))
print("multiples of seven:", first_three)
print(f"the source was pulled {len(log)} times, not 999")

TEXT = """First line
second line

A new paragraph
wrapped over two lines
"""
for paragraph in read_paragraphs(TEXT):
    print("-", paragraph)


# yield from delegates to another iterable.
def all_lines() -> Iterator[str]:
    yield "Amber"
    yield from ["Cobalt", "Emerald"]


print(list(all_lines()))


# send() passes a value back in at the yield.
def accumulator() -> Iterator[int]:
    total = 0
    while True:
        added = yield total
        total += added or 0


running = accumulator()
next(running)  # advance to the first yield
print(running.send(10), running.send(5), running.send(100))


# A generator's cleanup runs when it is closed or garbage collected.
def with_cleanup() -> Iterator[int]:
    try:
        yield 1
        yield 2
    finally:
        print("generator cleaned up")


values = with_cleanup()
print(next(values))
values.close()

# A generator expression is the same thing without the def.
squares = (n * n for n in range(10))
print("sum of squares:", sum(squares))
print("exhausted, so nothing is left:", list(squares))
