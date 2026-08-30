"""asyncio: awaiting one coroutine at a time, and several at once."""

import asyncio
import time


async def fetch(name: str, seconds: float) -> str:
    await asyncio.sleep(seconds)  # yields control, does not block the loop
    return f"{name} ready"


async def failing() -> str:
    await asyncio.sleep(0.02)
    raise RuntimeError("the upstream gave up")


async def main() -> None:
    started = time.perf_counter()
    await fetch("cached-report", 0.12)
    await fetch("full-export", 0.12)
    print(f"sequential took ~{(time.perf_counter() - started) * 1000:.0f} ms")

    # gather runs them concurrently and keeps the order of the arguments.
    started = time.perf_counter()
    results = await asyncio.gather(
        fetch("a", 0.12), fetch("b", 0.12), fetch("c", 0.08)
    )
    print(results, f"in ~{(time.perf_counter() - started) * 1000:.0f} ms")

    # One failure cancels gather unless return_exceptions is set.
    mixed = await asyncio.gather(fetch("ok", 0.02), failing(), return_exceptions=True)
    print("with return_exceptions:", [type(r).__name__ for r in mixed])

    # A task starts running as soon as it is created.
    task = asyncio.create_task(fetch("background", 0.05))
    print("doing other work while it runs")
    print(await task)

    # TaskGroup cancels its siblings when one of them fails.
    try:
        async with asyncio.TaskGroup() as group:
            group.create_task(fetch("sibling", 0.5))
            group.create_task(failing())
    except* RuntimeError as errors:
        print("task group failed with:", [str(e) for e in errors.exceptions])

    # A timeout cancels the coroutine underneath.
    try:
        async with asyncio.timeout(0.05):
            await fetch("slow", 0.5)
    except TimeoutError:
        print("timed out, and the coroutine was cancelled")

    # as_completed yields results in the order they finish.
    pending = [fetch("slow", 0.15), fetch("quick", 0.03), fetch("middle", 0.09)]
    for coroutine in asyncio.as_completed(pending):
        print("  finished:", await coroutine)

    # A queue hands work to a fixed number of workers.
    queue: asyncio.Queue[int] = asyncio.Queue()
    done: list[int] = []

    async def worker() -> None:
        while True:
            value = await queue.get()
            await asyncio.sleep(0.01)
            done.append(value * value)
            queue.task_done()

    workers = [asyncio.create_task(worker()) for _ in range(3)]
    for number in range(1, 10):
        queue.put_nowait(number)
    await queue.join()
    for task in workers:
        task.cancel()
    print("squares from the queue:", sorted(done))


asyncio.run(main())
