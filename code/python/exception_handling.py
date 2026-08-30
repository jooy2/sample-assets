"""Raising, catching, chaining, and grouping exceptions."""

import sys
from contextlib import suppress


class ValidationError(ValueError):
    """Carries the field alongside the message."""

    def __init__(self, field: str, message: str) -> None:
        super().__init__(message)
        self.field = field


class OutOfRangeZoneError(ValidationError):
    pass


def parse_zone(raw: str) -> int:
    try:
        zone = int(raw)
    except ValueError as error:
        # `from` records the cause, so the traceback shows both.
        raise ValidationError("zone", f"{raw!r} is not a number") from error

    if not 1 <= zone <= 6:
        raise OutOfRangeZoneError("zone", f"zone {zone} is outside 1-6")
    return zone


for raw in ["3", "9", "east"]:
    try:
        print(f"{raw:<6} -> zone {parse_zone(raw)}")
    except OutOfRangeZoneError as error:
        # The most specific handler has to come first.
        print(f"{raw:<6} -> out of range: {error}")
    except ValidationError as error:
        cause = type(error.__cause__).__name__
        print(f"{raw:<6} -> {error} (caused by {cause}) on field {error.field}")

# else runs when nothing was raised; finally runs either way.
for raw in ["2", "nine"]:
    try:
        zone = parse_zone(raw)
    except ValidationError:
        print(f"{raw:<6} rejected")
    else:
        print(f"{raw:<6} accepted as {zone}")
    finally:
        pass

# Several types in one handler.
try:
    raise TimeoutError("the upstream stopped answering")
except (ConnectionError, TimeoutError) as error:
    print("caught a", type(error).__name__)

# suppress() is a readable try/except/pass.
with suppress(ZeroDivisionError):
    _ = 1 / 0
print("division by zero ignored")

# An ExceptionGroup carries several failures at once; except* picks them apart.
def validate_all(values: list[str]) -> None:
    errors = []
    for value in values:
        try:
            parse_zone(value)
        except ValidationError as error:
            errors.append(error)
    if errors:
        raise ExceptionGroup("some zones were rejected", errors)


try:
    validate_all(["2", "9", "east", "4"])
except* OutOfRangeZoneError as group:
    print("out of range:", [str(e) for e in group.exceptions])
except* ValidationError as group:
    print("unparsable:", [str(e) for e in group.exceptions])

# Re-raising after logging keeps the original traceback.
def with_logging(raw: str) -> int:
    try:
        return parse_zone(raw)
    except ValidationError:
        print(f"  logging a failure for {raw!r}")
        raise


try:
    with_logging("twelve")
except ValidationError as error:
    frames = 0
    traceback = error.__traceback__
    while traceback is not None:
        frames += 1
        traceback = traceback.tb_next
    print("still the original:", error, f"| {frames} frames in the traceback")

# Custom cleanup, without hiding the failure.
def read_config() -> dict:
    handle = None
    try:
        handle = {"open": True}
        raise KeyError("missing section")
    finally:
        if handle is not None:
            print("  closed the handle")


with suppress(KeyError):
    read_config()

print("still running:", sys.exc_info() == (None, None, None))
