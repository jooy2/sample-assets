"""Decorators wrap a function: logging, caching, retrying, and registering."""

import functools
import time
from collections.abc import Callable
from typing import Any, TypeVar

F = TypeVar("F", bound=Callable[..., Any])


def timed(fn: F) -> F:
    """functools.wraps keeps the name and docstring of the wrapped function."""

    @functools.wraps(fn)
    def wrapper(*args: Any, **kwargs: Any) -> Any:
        started = time.perf_counter()
        result = fn(*args, **kwargs)
        print(f"  {fn.__name__} took {(time.perf_counter() - started) * 1000:.2f} ms")
        return result

    return wrapper  # type: ignore[return-value]


def retry(attempts: int = 3, delay: float = 0.01) -> Callable[[F], F]:
    """A decorator that takes arguments needs one more level of nesting."""

    def decorate(fn: F) -> F:
        @functools.wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            for attempt in range(1, attempts + 1):
                try:
                    return fn(*args, **kwargs)
                except RuntimeError as error:
                    print(f"  attempt {attempt} failed: {error}")
                    if attempt == attempts:
                        raise
                    time.sleep(delay)
            raise AssertionError("unreachable")

        return wrapper  # type: ignore[return-value]

    return decorate


HANDLERS: dict[str, Callable[[str], str]] = {}


def handles(event: str) -> Callable[[F], F]:
    """A registry decorator: the side effect is the point."""

    def decorate(fn: F) -> F:
        HANDLERS[event] = fn
        return fn

    return decorate


@timed
def count_primes(limit: int) -> int:
    """Counts the primes below a limit."""
    composite = bytearray(limit + 1)
    found = 0
    for candidate in range(2, limit + 1):
        if composite[candidate]:
            continue
        found += 1
        composite[candidate * candidate :: candidate] = bytes(
            len(range(candidate * candidate, limit + 1, candidate))
        )
    return found


@functools.lru_cache(maxsize=None)
def slow_square(value: int) -> int:
    time.sleep(0.01)
    return value * value


attempts_made = 0


@retry(attempts=3)
def flaky() -> str:
    global attempts_made
    attempts_made += 1
    if attempts_made < 3:
        raise RuntimeError("the upstream gave up")
    return f"succeeded on attempt {attempts_made}"


@handles("reading")
def on_reading(payload: str) -> str:
    return f"logged {payload}"


@handles("alarm")
def on_alarm(payload: str) -> str:
    return f"paged someone about {payload}"


print("primes below 200000:", count_primes(200_000))
print("name survived the decorator:", count_primes.__name__, "-", count_primes.__doc__)

with_timing = time.perf_counter()
print(slow_square(12), slow_square(12), slow_square(9))
print(f"three calls, two cached, in {(time.perf_counter() - with_timing) * 1000:.0f} ms")
print("cache:", slow_square.cache_info())

print(flaky())

print("registered:", sorted(HANDLERS))
print(HANDLERS["alarm"]("SNS-04 at 31.2C"))
