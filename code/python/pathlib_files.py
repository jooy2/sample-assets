"""pathlib: paths as objects, and the file operations hanging off them."""

import csv
import os
from pathlib import Path
from tempfile import TemporaryDirectory

with TemporaryDirectory(prefix="sample-assets-") as directory:
    base = Path(directory)

    # The / operator joins, whatever the platform's separator is.
    data = base / "datasets" / "csv"
    data.mkdir(parents=True, exist_ok=True)

    stations = data / "stations.csv"
    rows = [
        ["station", "line", "zone"],
        ["Alder Cross", "Amber", 2],
        ["Quill Wharf", "Cobalt", 3],
        ["Saltwick Halt", "Amber", 5],
        ["Nether Gate", "Emerald", 2],
    ]

    with stations.open("w", newline="", encoding="utf-8") as handle:
        csv.writer(handle).writerows(rows)

    print(f"wrote {stations.stat().st_size} bytes to {stations.relative_to(base)}")

    # The parts of a path, without any string surgery.
    print("name:", stations.name, "| stem:", stations.stem, "| suffix:", stations.suffix)
    print("parent:", stations.parent.name, "| parents:", [p.name for p in stations.parents][:3])
    print("absolute:", stations.is_absolute(), "| exists:", stations.exists())

    # Whole-file helpers for anything small.
    print("first line:", stations.read_text(encoding="utf-8").splitlines()[0])

    # Streaming, for anything that is not.
    with stations.open(encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        zones = [int(row["zone"]) for row in reader]
    print(f"average zone {sum(zones) / len(zones):.2f}")

    # Writing more files, then finding them again.
    for index in range(3):
        (base / f"report-{index}.txt").write_text(f"report {index}\n", encoding="utf-8")
    (base / "notes.md").write_text("# notes\n", encoding="utf-8")

    print("top level:", sorted(p.name for p in base.iterdir()))
    print("txt files:", sorted(p.name for p in base.glob("*.txt")))
    print("every csv, at any depth:", [str(p.relative_to(base)) for p in base.rglob("*.csv")])
    print("total bytes:", sum(p.stat().st_size for p in base.rglob("*") if p.is_file()))

    # Renaming, copying by hand, and deleting.
    renamed = (base / "notes.md").rename(base / "README.md")
    print("renamed to:", renamed.name)

    copy = base / "stations-copy.csv"
    copy.write_bytes(stations.read_bytes())
    print("copied:", copy.stat().st_size == stations.stat().st_size)

    copy.unlink()
    print("deleted:", not copy.exists())

    # missing_ok keeps a delete from raising when there is nothing to delete.
    (base / "never-existed.txt").unlink(missing_ok=True)

    # with_suffix and with_name build a sibling path.
    print("as tsv:", stations.with_suffix(".tsv").name)
    print("sibling:", stations.with_name("orders.csv").name)

    print("home is absolute:", Path.home().is_absolute(), "| cwd:", Path.cwd() == Path(os.getcwd()))

print("the temporary directory is gone:", not Path(directory).exists())
