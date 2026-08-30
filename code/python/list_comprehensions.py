"""Comprehensions for lists, sets, dicts, and generators."""

stations = [
    {"name": "Alder Cross", "line": "Amber", "zone": 2, "platforms": 2, "step_free": True},
    {"name": "Quill Wharf", "line": "Cobalt", "zone": 3, "platforms": 4, "step_free": False},
    {"name": "Saltwick Halt", "line": "Amber", "zone": 5, "platforms": 1, "step_free": True},
    {"name": "Nether Gate", "line": "Emerald", "zone": 2, "platforms": 3, "step_free": True},
    {"name": "Bramble Fields", "line": "Cobalt", "zone": 4, "platforms": 2, "step_free": False},
]

# Map and filter in one expression.
accessible = sorted(s["name"] for s in stations if s["step_free"] and s["zone"] <= 3)
print("step free, zone 3 or closer:", accessible)

# A conditional expression in the value position transforms every element.
labels = [f"{s['name']} ({'step free' if s['step_free'] else 'stairs'})" for s in stations]
print(*labels, sep="\n")

# Dict comprehension: build a lookup in one line.
zones = {s["name"]: s["zone"] for s in stations}
print("Quill Wharf ->", zones["Quill Wharf"])

# Set comprehension: duplicates disappear.
print("lines:", {s["line"] for s in stations})

# Nested loops read in the order they are written.
words = [word for s in stations for word in s["name"].split()]
print("words:", words)

grid = [[row * column for column in range(1, 5)] for row in range(1, 4)]
print("grid:", grid)

# A generator expression computes lazily, so nothing is held in memory.
total = sum(s["platforms"] for s in stations)
print("platforms:", total)
print("any in zone 5:", any(s["zone"] == 5 for s in stations))
print("all have platforms:", all(s["platforms"] > 0 for s in stations))

# The walrus operator reuses a computed value inside the comprehension.
lengths = [length for s in stations if (length := len(s["name"])) > 11]
print("long name lengths:", lengths)

# Comprehensions have their own scope, so they cannot leak a loop variable.
squares = [n * n for n in range(5)]
print("squares:", squares, "| n is not defined out here:", "n" not in dir())

# When a comprehension stops being readable, a loop is the better tool.
by_line: dict[str, list[str]] = {}
for station in stations:
    by_line.setdefault(station["line"], []).append(station["name"])
print("grouped:", by_line)
