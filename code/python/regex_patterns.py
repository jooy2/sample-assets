"""Regular expressions: matching, capturing, named groups, and replacing."""

import re

LOG = re.compile(
    r"^(?P<ip>\S+) \S+ (?P<user>\S+) \[(?P<time>[^\]]+)\] "
    r'"(?P<method>[A-Z]+) (?P<path>\S+) [^"]+" (?P<status>\d{3}) (?P<bytes>\d+)$'
)

lines = [
    '203.0.113.183 - - [10/Nov/2025:00:02:25 +0000] "GET /api/v1/orders HTTP/2.0" 200 6776',
    '192.0.2.125 - imogen.hawthorne [10/Nov/2025:00:05:17 +0000] "POST /login HTTP/1.1" 302 312',
    "not a log line at all",
]

for line in lines:
    match = LOG.match(line)
    if match is None:
        print("unparsed:", line)
        continue
    fields = match.groupdict()
    print(f"{fields['status']} {fields['method']:<4} {fields['path']:<16} from {fields['ip']}")

# finditer walks every match without building a list first.
csv_text = "Alder Cross,Amber,2;Quill Wharf,Cobalt,3;Saltwick Halt,Amber,5"
for match in re.finditer(r"(?P<name>[^,;]+),(?P<line>[^,;]+),(?P<zone>\d+)", csv_text):
    print(f"  {match['name']} is on {match['line']}, zone {match['zone']}")

# findall returns the groups when there are any, the whole match otherwise.
print("zones:", re.findall(r",(\d+)", csv_text))
print("words:", re.findall(r"\b[A-Z]\w+", csv_text))

# sub with a template, and with a function.
print(re.sub(r"(?P<y>\d{4})-(?P<m>\d{2})-(?P<d>\d{2})", r"\g<d>/\g<m>/\g<y>", "2025-11-03"))
print(re.sub(r"zone (\d)", lambda m: f"zone {int(m[1]) + 1}", "zone 2, zone 5"))
print("count:", re.subn(r"[aeiou]", "*", "Alder Cross")[1], "vowels replaced")

# split on a pattern, optionally keeping what was split on.
print(re.split(r"\s*[,;]\s*", "amber ,cobalt;  emerald"))
print(re.split(r"(\d+)", "one1two22three"))

# Lookahead and lookbehind match without consuming.
print(re.sub(r"\B(?=(\d{3})+(?!\d))", ",", "1234567"))
print(re.search(r"(?<=\$)[\d.]+", "price: $74.50")[0])

# Flags: IGNORECASE, MULTILINE, DOTALL, and VERBOSE for readable patterns.
text = "Amber line\ncobalt LINE"
print(re.findall(r"^\w+ line$", text, re.IGNORECASE | re.MULTILINE))

TIMESTAMP = re.compile(
    r"""
    (?P<day>\d{2}) /       # 10/
    (?P<month>[A-Za-z]{3}) /   # Nov/
    (?P<year>\d{4})            # 2025
    """,
    re.VERBOSE,
)
print(TIMESTAMP.search("10/Nov/2025:00:02:25").groupdict())

# Escaping user input before it becomes part of a pattern.
needle = re.compile(re.escape("a.b"))
print("literal dot only:", needle.findall("a.b axb a.b"))

# fullmatch anchors both ends without \A and \Z.
print("valid id:", bool(re.fullmatch(r"ST-\d{3}", "ST-001")), bool(re.fullmatch(r"ST-\d{3}", "ST-1")))

# Compiling once is worth it inside a loop; re caches recent patterns anyway.
print("cache:", re.purge() is None)
