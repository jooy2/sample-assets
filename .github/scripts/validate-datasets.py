#!/usr/bin/env python3
"""Check that every file under `datasets/` is what its extension claims it is.

Run it from the repository root:

    python3 .github/scripts/validate-datasets.py

A file whose name marks it as deliberately broken - it contains `-malformed`,
`-invalid`, or `-broken` - is only checked for its name and its location, never
for its content. Those samples exist to break parsers on purpose.
"""

from __future__ import annotations

import csv
import json
import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASETS = ROOT / "datasets"

# Which extensions belong in which format folder.
FOLDER_EXTENSIONS = {
    "csv": {".csv"},
    "json": {".json", ".jsonl", ".ndjson"},
    "sql": {".sql"},
    "tsv": {".tsv"},
    "txt": {".txt"},
    "xml": {".xml"},
    "yaml": {".yaml", ".yml"},
}

FILE_NAME = re.compile(r"^[a-z0-9]+(?:[.-][a-z0-9]+)*$")
INTENTIONALLY_BROKEN = ("-malformed", "-invalid", "-broken")

errors: list[str] = []


def fail(path: Path, message: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {message}")


def check_json(path: Path, text: str) -> None:
    if path.suffix == ".json":
        json.loads(text)
        return
    for number, line in enumerate(text.splitlines(), start=1):
        if line.strip():
            try:
                json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(f"line {number}: {error}") from error


def check_csv(path: Path, text: str) -> None:
    delimiter = "\t" if path.suffix == ".tsv" else ","
    rows = list(csv.reader(text.splitlines(), delimiter=delimiter))
    if not rows:
        raise ValueError("the file is empty")
    width = len(rows[0])
    for number, row in enumerate(rows[1:], start=2):
        if len(row) != width:
            raise ValueError(
                f"row {number} has {len(row)} fields, but the header has {width}"
            )


CONTENT_CHECKS = {
    ".json": check_json,
    ".jsonl": check_json,
    ".ndjson": check_json,
    ".csv": check_csv,
    ".tsv": check_csv,
    ".xml": lambda path, text: ElementTree.fromstring(text),
}

try:
    import yaml  # type: ignore[import-not-found]

    CONTENT_CHECKS[".yaml"] = lambda path, text: yaml.safe_load(text)
    CONTENT_CHECKS[".yml"] = CONTENT_CHECKS[".yaml"]
except ImportError:
    print("PyYAML is not installed, so YAML files are only checked for encoding.")


def main() -> int:
    if not DATASETS.is_dir():
        print("No `datasets` folder to check.")
        return 0

    files = [
        path
        for path in sorted(DATASETS.rglob("*"))
        if path.is_file() and path.name != ".gitkeep" and path.suffix != ".md"
    ]

    if not files:
        print("No dataset files to check yet.")
        return 0

    for path in files:
        relative = path.relative_to(DATASETS)
        folder = relative.parts[0] if len(relative.parts) > 1 else None

        if not FILE_NAME.match(path.name):
            fail(path, "the name must be lowercase, and use only `a-z`, `0-9`, `-`, `.`")

        if folder is None:
            fail(path, "a dataset belongs in a format folder, not in `datasets/` itself")
        elif folder not in FOLDER_EXTENSIONS:
            fail(path, f"`{folder}` is not a known format folder")
        elif path.suffix not in FOLDER_EXTENSIONS[folder]:
            expected = ", ".join(sorted(FOLDER_EXTENSIONS[folder]))
            fail(path, f"`{path.suffix}` does not belong in `{folder}/` (expected {expected})")

        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as error:
            fail(path, f"the file is not valid UTF-8 ({error})")
            continue

        if any(marker in path.stem for marker in INTENTIONALLY_BROKEN):
            continue

        check = CONTENT_CHECKS.get(path.suffix)
        if check is None:
            continue

        try:
            check(path, text)
        except Exception as error:  # noqa: BLE001 - report whatever the parser raised
            fail(path, f"invalid {path.suffix.lstrip('.')} ({error})")

    if errors:
        print(f"{len(errors)} problem(s) found in {len(files)} file(s):\n")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"All {len(files)} dataset file(s) are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
