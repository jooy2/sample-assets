"""The containers in `collections`, which cover what dict and list do not."""

from collections import ChainMap, Counter, defaultdict, deque, namedtuple, OrderedDict

TEXT = """
The tide came in and the tide went out
and the shore stayed where it was
"""

# Counter: counting anything hashable, with the ranking built in.
words = Counter(TEXT.lower().split())
print("distinct words:", len(words))
print("most common:", words.most_common(3))
print("count of 'tide':", words["tide"], "| of 'ferry':", words["ferry"])

letters = Counter(TEXT.replace(" ", "").replace("\n", ""))
print("top letters:", "".join(letter for letter, _ in letters.most_common(5)))

# Counters support arithmetic.
morning = Counter({"Alder Cross": 420, "Quill Wharf": 310})
evening = Counter({"Alder Cross": 380, "Saltwick Halt": 90})
print("combined:", dict(morning + evening))
print("difference:", dict(morning - evening))

# defaultdict builds the missing value instead of raising KeyError.
by_line = defaultdict(list)
for name, line in [("Alder Cross", "Amber"), ("Quill Wharf", "Cobalt"), ("Saltwick Halt", "Amber")]:
    by_line[line].append(name)
print("grouped:", dict(by_line))

tally = defaultdict(int)
for character in "mississippi":
    tally[character] += 1
print("tally:", dict(tally))

# deque: fast appends and pops at both ends, and a bounded history.
queue = deque(["Alder Cross", "Quill Wharf"])
queue.appendleft("Nether Gate")
queue.append("Saltwick Halt")
print("queue:", list(queue), "| popped", queue.popleft(), "and", queue.pop())

recent = deque(maxlen=3)
for reading in [21.4, 19.8, 24.1, 22.7, 18.9]:
    recent.append(reading)
print("last three readings:", list(recent))

queue.rotate(1)
print("rotated:", list(queue))

# namedtuple: a tuple whose fields have names.
Reading = namedtuple("Reading", "device celsius battery")
reading = Reading("SNS-01", 21.4, 88)
print(reading, "| device:", reading.device, "| as a dict:", reading._asdict())
print("replaced:", reading._replace(battery=74))

# ChainMap searches several mappings in order, without merging them.
defaults = {"zone": 1, "platforms": 2, "step_free": False}
overrides = {"zone": 3}
settings = ChainMap(overrides, defaults)
print("resolved:", dict(settings), "| zone came from the overrides:", settings["zone"])

# OrderedDict still differs from dict in one way: order counts for equality.
print("dict equality ignores order:", {"a": 1, "b": 2} == {"b": 2, "a": 1})
print(
    "OrderedDict equality does not:",
    OrderedDict(a=1, b=2) == OrderedDict(b=2, a=1),
)
