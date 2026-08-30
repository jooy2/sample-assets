"""itertools: the lazy building blocks, and a few recipes made from them."""

from collections.abc import Iterable, Iterator
from itertools import (
    accumulate, chain, combinations, count, cycle, dropwhile, groupby,
    islice, pairwise, permutations, product, repeat, starmap, takewhile, tee,
    zip_longest,
)
from operator import itemgetter

stations = [
    {"name": "Alder Cross", "line": "Amber", "zone": 2},
    {"name": "Saltwick Halt", "line": "Amber", "zone": 5},
    {"name": "Quill Wharf", "line": "Cobalt", "zone": 3},
    {"name": "Bramble Fields", "line": "Cobalt", "zone": 4},
    {"name": "Nether Gate", "line": "Emerald", "zone": 2},
]

# Infinite iterators, cut down with islice.
print(list(islice(count(10, 5), 5)))
print(list(islice(cycle("ABC"), 7)))
print(list(repeat("Amber", 3)))

# chain flattens; product, permutations, and combinations enumerate.
print(list(chain([1, 2], [3, 4], [5])))
print(list(product("AB", [1, 2])))
print(list(permutations("ABC", 2))[:3], "...")
print(list(combinations(["Amber", "Cobalt", "Emerald"], 2)))

# accumulate is a running fold; pairwise gives overlapping pairs.
print(list(accumulate([1, 2, 3, 4, 5])))
print(list(accumulate([1, 2, 3, 4, 5], max)))
print(list(pairwise([1, 4, 9, 16])))

# groupby needs the input sorted by the same key, which is the usual trap.
for line, group in groupby(sorted(stations, key=itemgetter("line")), key=itemgetter("line")):
    print(f"  {line}: {[s['name'] for s in group]}")

# takewhile and dropwhile stop or start at the first failure.
readings = [18.2, 19.6, 21.4, 24.8, 19.1]
print("rising run:", list(takewhile(lambda c: c < 22, readings)))
print("after it:", list(dropwhile(lambda c: c < 22, readings)))

# starmap unpacks each item into the function's arguments.
print(list(starmap(lambda name, zone: f"{name}={zone}", [("Alder", 2), ("Quill", 3)])))

# zip stops at the shortest; zip_longest fills instead.
print(list(zip("abc", [1, 2])))
print(list(zip_longest("abc", [1, 2], fillvalue="-")))

# tee splits one iterator into several, buffering what the slowest has not read.
source = (n * n for n in range(6))
left, right = tee(source, 2)
print(list(left), list(right))


def chunked(iterable: Iterable, size: int) -> Iterator[tuple]:
    """A recipe: fixed-size chunks, without padding the last one."""
    iterator = iter(iterable)
    while chunk := tuple(islice(iterator, size)):
        yield chunk


def flatten(nested: Iterable[Iterable]) -> Iterator:
    return chain.from_iterable(nested)


def unique(iterable: Iterable) -> Iterator:
    seen = set()
    for value in iterable:
        if value not in seen:
            seen.add(value)
            yield value


print("chunked:", list(chunked(range(1, 11), 4)))
print("flattened:", list(flatten([[1, 2], [3], [4, 5]])))
print("unique, order kept:", list(unique("mississippi")))
