"""`with` blocks: the class protocol, the decorator, and the ones in
contextlib."""

import time
from contextlib import contextmanager, suppress, ExitStack
from collections.abc import Iterator
from pathlib import Path
from tempfile import TemporaryDirectory


class Timer:
    """A context manager written the long way, as a class."""

    def __init__(self, label: str) -> None:
        self.label = label
        self.elapsed = 0.0

    def __enter__(self) -> "Timer":
        self._started = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> bool:
        self.elapsed = time.perf_counter() - self._started
        print(f"  {self.label} took {self.elapsed * 1000:.2f} ms")
        return False  # returning True would swallow the exception


@contextmanager
def workspace(name: str) -> Iterator[Path]:
    """The same idea as a generator: setup, yield, teardown."""
    with TemporaryDirectory(prefix=name) as directory:
        path = Path(directory)
        print(f"  created {path.name}")
        try:
            yield path
        finally:
            print(f"  removing {path.name}")


with Timer("counting"):
    total = sum(range(2_000_000))
print("sum:", total)

with workspace("sample-assets-") as directory:
    (directory / "stations.csv").write_text("station,line,zone\nAlder Cross,Amber,2\n")
    print("  files:", [p.name for p in directory.iterdir()])

# The teardown still runs when the body raises.
try:
    with workspace("failing-"):
        raise RuntimeError("interrupted halfway")
except RuntimeError as error:
    print("caught:", error)

# suppress() replaces a try/except/pass.
with suppress(FileNotFoundError):
    Path("/definitely/not/here.csv").read_text()
print("missing file ignored")

# Several managers in one with statement, closed in reverse order.
with TemporaryDirectory() as one, TemporaryDirectory() as two:
    print("two directories open:", Path(one).exists(), Path(two).exists())

# ExitStack handles a number of managers that is only known at runtime.
with TemporaryDirectory() as directory:
    base = Path(directory)
    with ExitStack() as stack:
        files = [
            stack.enter_context((base / f"part-{index}.txt").open("w"))
            for index in range(3)
        ]
        for index, handle in enumerate(files):
            handle.write(f"part {index}\n")
        print("open handles:", len(files))
    print("all closed:", all(handle.closed for handle in files))
