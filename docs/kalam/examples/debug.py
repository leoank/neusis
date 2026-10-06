"""
A sample file for poking at kalam's debug stack (nvim-dap +
nvim-dap-view + nvim-dap-python).

What to try, in increasing complexity:

  1. Place a breakpoint on the `result = fibonacci(...)` line in
     main() with `<leader>db` (or click the gutter once dap is
     running).
  2. `<leader>dc` to start. The debugger should stop at the
     breakpoint. `<leader>du` opens the dap-view panel with
     scopes/stacks/watches/breakpoints/repl.
  3. `<leader>di` to step INTO `fibonacci`. Watch `n` change in
     the Scopes pane as the recursion unrolls.
  4. `<leader>do` to step out of one level.
  5. `<leader>ds` to step OVER (advance past a call without
     descending into it).
  6. `<leader>de` on a variable name to hover its current value
     (e.g. on `n` inside fibonacci).
  7. Set a CONDITIONAL breakpoint inside the loop in
     Stats.median() with `<leader>dB` and condition `len(self.values)
     > 5` — only stops when the list has more than five entries.
  8. `<leader>dr` opens the dap-python repl — evaluate any
     expression in the current frame (e.g. `self.values[0]`).
  9. Inside `test_fibonacci`, `<leader>dPm` runs JUST this test
     under the debugger (uses pytest by default).
  10. `divide_by_user_input` raises ZeroDivisionError on input "0"
      — uncomment the call in main() and turn on exception
      breakpoints (`:lua require('dap').set_exception_breakpoints({"raised"})`)
      to stop at the raise site.

Run modes:
  * Script:        `:lua require('dap').continue()` then pick
                   "Launch file" — debugs THIS file directly.
  * Single method: place cursor on `test_fibonacci`, hit
                   `<leader>dPm`.
  * Class methods: cursor on `Stats`, `<leader>dPc`.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


# 1. Pure-function recursion — good for step-into demos.
def fibonacci(n: int) -> int:
    """Naive recursive fibonacci. O(2^n); slow on purpose so the
    debugger has somewhere to land on every recursion."""
    if n < 0:
        raise ValueError(f"fibonacci undefined for n < 0 (got {n})")
    if n < 2:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)


# 2. Class + method calls — exercises Stats stepping and dap's
#    scope inspection (look at `self.values` while stepping
#    through median()).
@dataclass
class Stats:
    values: list[float]

    def mean(self) -> float:
        if not self.values:
            raise ValueError("can't take the mean of an empty list")
        return sum(self.values) / len(self.values)

    def median(self) -> float:
        # Intentional implementation that does a bit of work per
        # iteration — set a conditional breakpoint here on
        # `mid > 2` and watch how `sorted_values` evolves.
        sorted_values = sorted(self.values)
        n = len(sorted_values)
        if n == 0:
            raise IndexError("median of an empty list is undefined")
        mid = n // 2
        if n % 2 == 1:
            return sorted_values[mid]
        return (sorted_values[mid - 1] + sorted_values[mid]) / 2


# 3. An exception path — uncomment the call in main() to trigger
#    a ZeroDivisionError. Turn on "stop on exception raised" first
#    to see how dap pauses at the raise site.
def divide_by_user_input(numerator: float, denominator_str: str) -> float:
    denominator = float(denominator_str)
    return numerator / denominator


# 4. A tiny pytest-style test — `<leader>dPm` on the cursor over
#    `test_fibonacci` runs JUST this under the debugger. Place a
#    breakpoint on the assert to see what's about to be compared.
def test_fibonacci() -> None:
    assert fibonacci(0) == 0
    assert fibonacci(1) == 1
    assert fibonacci(5) == 5
    assert fibonacci(10) == 55


# 5. A test that uses Stats — exercises stepping through both
#    user code and stdlib code (the sorted() call).
def test_stats_median() -> None:
    s = Stats(values=[3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0])
    assert s.median() == 3.5


def iterable_sum(items: Iterable[int]) -> int:
    # Generator-fed loop — useful for stepping through with `]s`
    # and watching `running` change.
    running = 0
    for item in items:
        running += item
    return running


def main() -> None:
    # Place a breakpoint on the next line and `<leader>dc`.
    result = fibonacci(8)
    print(f"fibonacci(8) = {result}")

    sample = Stats(values=[3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0])
    print(f"mean   = {sample.mean()}")
    print(f"median = {sample.median()}")

    total = iterable_sum(range(1, 11))
    print(f"sum of 1..10 = {total}")

    # Uncomment to exercise the exception-breakpoint flow:
    # print(divide_by_user_input(10, "0"))


if __name__ == "__main__":
    main()
