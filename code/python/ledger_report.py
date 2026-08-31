#!/usr/bin/env python3
"""A double-entry ledger: parser, validator, and report writer.

Reads a plain-text ledger in the format below, checks that every transaction
balances, and prints a trial balance, a balance sheet, an income statement, and
a monthly cash-flow summary.

    2027-01-05 * Opening balance
        Assets:Bank:Current            4200.00 GBP
        Equity:Opening

    2027-01-08 * Rent for January
        Expenses:Housing:Rent          1450.00 GBP
        Assets:Bank:Current

A posting with no amount takes whatever is needed to make the transaction sum
to zero; at most one such posting is allowed per transaction. Account names are
colon-separated paths, and reports roll them up by prefix.

Run it against a file, or with no arguments to use the built-in example:

    python3 ledger_report.py my-ledger.txt
    python3 ledger_report.py --report balance-sheet my-ledger.txt

Every figure in the built-in example is invented.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Iterable, Iterator


# --------------------------------------------------------------------- errors


class LedgerError(Exception):
    """A problem with the ledger file, reported with a line number."""

    def __init__(self, line_number: int, message: str) -> None:
        super().__init__(f"line {line_number}: {message}")
        self.line_number = line_number
        self.message = message


# ---------------------------------------------------------------------- model


@dataclass(frozen=True)
class Posting:
    """One leg of a transaction: an account and a signed amount."""

    account: str
    amount: Decimal
    currency: str

    @property
    def parts(self) -> tuple[str, ...]:
        return tuple(self.account.split(":"))

    @property
    def root(self) -> str:
        return self.parts[0]


@dataclass
class Transaction:
    """A dated, balanced group of postings."""

    when: date
    description: str
    postings: list[Posting] = field(default_factory=list)
    cleared: bool = True
    tags: tuple[str, ...] = ()
    line_number: int = 0

    @property
    def total(self) -> Decimal:
        return sum((p.amount for p in self.postings), Decimal("0"))

    def touches(self, prefix: str) -> bool:
        return any(
            p.account == prefix or p.account.startswith(prefix + ":")
            for p in self.postings
        )


# --------------------------------------------------------------------- parser

HEADER = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})\s+"
    r"(?P<flag>[*!])?\s*"
    r"(?P<description>[^;]*?)"
    r"(?:\s*;\s*(?P<tags>.*))?$"
)

# An account name may contain single spaces ("Eating out"); it is two or more
# spaces that separate the account from its amount.
POSTING = re.compile(
    r"^\s+(?P<account>[A-Za-z][\w:&'-]*(?: [\w:&'-]+)*)"
    r"(?:\s{2,}(?P<amount>-?[\d,]+(?:\.\d+)?)\s*(?P<currency>[A-Z]{3})?)?"
    r"\s*(?:;.*)?$"
)


def parse(lines: Iterable[str]) -> list[Transaction]:
    """Parse a ledger into transactions, raising on the first problem."""
    transactions: list[Transaction] = []
    current: Transaction | None = None
    blank_posting_line: int | None = None

    for number, raw in enumerate(lines, start=1):
        line = raw.rstrip("\n")

        if not line.strip() or line.lstrip().startswith(("#", ";")):
            if current is not None and not line.strip():
                finish(current, blank_posting_line, transactions)
                current, blank_posting_line = None, None
            continue

        if not line[0].isspace():
            if current is not None:
                finish(current, blank_posting_line, transactions)
                blank_posting_line = None
            current = parse_header(line, number)
            continue

        if current is None:
            raise LedgerError(number, "posting outside a transaction")

        account, amount, currency = parse_posting(line, number)
        if amount is None:
            if blank_posting_line is not None:
                raise LedgerError(
                    number, "a transaction may have only one balancing posting"
                )
            blank_posting_line = number
            current.postings.append(Posting(account, Decimal("0"), currency or "GBP"))
        else:
            current.postings.append(Posting(account, amount, currency or "GBP"))

    if current is not None:
        finish(current, blank_posting_line, transactions)

    return transactions


def parse_header(line: str, number: int) -> Transaction:
    match = HEADER.match(line)
    if match is None:
        raise LedgerError(number, f"cannot read transaction header: {line!r}")

    try:
        when = date.fromisoformat(match.group("date"))
    except ValueError as error:
        raise LedgerError(number, f"bad date: {error}") from error

    description = (match.group("description") or "").strip()
    if not description:
        raise LedgerError(number, "transaction has no description")

    tags = tuple(
        tag.strip() for tag in (match.group("tags") or "").split(",") if tag.strip()
    )

    return Transaction(
        when=when,
        description=description,
        cleared=match.group("flag") != "!",
        tags=tags,
        line_number=number,
    )


def parse_posting(line: str, number: int) -> tuple[str, Decimal | None, str | None]:
    match = POSTING.match(line)
    if match is None:
        raise LedgerError(number, f"cannot read posting: {line.strip()!r}")

    raw_amount = match.group("amount")
    if raw_amount is None:
        return match.group("account"), None, match.group("currency")

    try:
        amount = Decimal(raw_amount.replace(",", ""))
    except InvalidOperation as error:
        raise LedgerError(number, f"bad amount: {raw_amount!r}") from error

    return match.group("account"), amount, match.group("currency")


def finish(
    transaction: Transaction,
    balancing_line: int | None,
    out: list[Transaction],
) -> None:
    """Fill in a balancing posting if there is one, then check the sum."""
    if len(transaction.postings) < 2:
        raise LedgerError(
            transaction.line_number,
            f"{transaction.description!r} needs at least two postings",
        )

    currencies = {p.currency for p in transaction.postings}
    if len(currencies) > 1:
        raise LedgerError(
            transaction.line_number,
            f"mixed currencies in one transaction: {', '.join(sorted(currencies))}",
        )

    if balancing_line is not None:
        residual = -sum(
            (p.amount for p in transaction.postings), Decimal("0")
        )
        for index, posting in enumerate(transaction.postings):
            if posting.amount == 0:
                transaction.postings[index] = Posting(
                    posting.account, residual, posting.currency
                )
                break

    if transaction.total != 0:
        raise LedgerError(
            transaction.line_number,
            f"{transaction.description!r} does not balance; "
            f"off by {transaction.total}",
        )

    out.append(transaction)


# -------------------------------------------------------------------- queries


def balances(transactions: Iterable[Transaction]) -> dict[str, Decimal]:
    """Closing balance for every account that appears."""
    totals: dict[str, Decimal] = defaultdict(Decimal)
    for transaction in transactions:
        for posting in transaction.postings:
            totals[posting.account] += posting.amount
    return dict(totals)


def roll_up(totals: dict[str, Decimal]) -> dict[str, Decimal]:
    """Add every account's balance into each of its parent prefixes."""
    rolled: dict[str, Decimal] = defaultdict(Decimal)
    for account, amount in totals.items():
        parts = account.split(":")
        for depth in range(1, len(parts) + 1):
            rolled[":".join(parts[:depth])] += amount
    return dict(rolled)


def by_month(
    transactions: Iterable[Transaction], prefix: str
) -> dict[str, Decimal]:
    """Monthly movement on one account subtree."""
    monthly: dict[str, Decimal] = defaultdict(Decimal)
    for transaction in transactions:
        for posting in transaction.postings:
            if posting.account == prefix or posting.account.startswith(prefix + ":"):
                monthly[transaction.when.strftime("%Y-%m")] += posting.amount
    return dict(monthly)


def descendants(totals: dict[str, Decimal], prefix: str) -> list[str]:
    return sorted(
        account
        for account in totals
        if account == prefix or account.startswith(prefix + ":")
    )


# -------------------------------------------------------------------- reports


def money(amount: Decimal, width: int = 12) -> str:
    """Right-aligned, two decimal places, negatives in parentheses."""
    quantised = amount.quantize(Decimal("0.01"))
    if quantised < 0:
        text = f"({-quantised:,.2f})"
    else:
        text = f"{quantised:,.2f}"
    return text.rjust(width)


def indent_account(account: str) -> str:
    depth = account.count(":")
    return "  " * depth + account.split(":")[-1]


def rule(width: int = 58, char: str = "-") -> str:
    return char * width


def trial_balance(transactions: list[Transaction]) -> list[str]:
    totals = balances(transactions)
    lines = ["Trial balance", rule(64), f"{'Account':<36}{'Debit':>13}{'Credit':>15}"]
    debits = Decimal("0")
    credits = Decimal("0")

    for account in sorted(totals):
        amount = totals[account]
        if amount == 0:
            continue
        if amount > 0:
            debits += amount
            lines.append(f"{account:<36}{money(amount, 13)}{'':>15}")
        else:
            credits += -amount
            lines.append(f"{account:<36}{'':>13}{money(-amount, 15)}")

    lines.append(rule(64))
    lines.append(f"{'Totals':<36}{money(debits, 13)}{money(credits, 15)}")
    difference = debits - credits
    lines.append(
        "In balance." if difference == 0 else f"OUT BY {difference}"
    )
    return lines


def balance_sheet(transactions: list[Transaction], as_at: date) -> list[str]:
    upto = [t for t in transactions if t.when <= as_at]
    rolled = roll_up(balances(upto))

    lines = [f"Balance sheet as at {as_at.isoformat()}", rule()]

    for section, sign in (("Assets", 1), ("Liabilities", -1), ("Equity", -1)):
        if section not in rolled:
            continue
        lines.append(section)
        for account in descendants(rolled, section):
            if account == section:
                continue
            value = rolled[account] * sign
            if value == 0:
                continue
            lines.append(f"  {indent_account(account):<36}{money(value)}")
        lines.append(f"  {'Total ' + section.lower():<36}{money(rolled[section] * sign)}")
        lines.append("")

    assets = rolled.get("Assets", Decimal("0"))
    liabilities = -rolled.get("Liabilities", Decimal("0"))
    equity = -rolled.get("Equity", Decimal("0"))
    retained = assets - liabilities - equity

    lines.append(rule())
    lines.append(f"{'Assets':<38}{money(assets)}")
    lines.append(f"{'Liabilities':<38}{money(liabilities)}")
    lines.append(f"{'Equity':<38}{money(equity)}")
    lines.append(f"{'Retained (income less expenses)':<38}{money(retained)}")
    lines.append(rule(58, "="))
    lines.append(
        f"{'Assets less liabilities and equity':<38}{money(assets - liabilities - equity - retained)}"
    )
    return lines


def income_statement(
    transactions: list[Transaction], start: date, end: date
) -> list[str]:
    window = [t for t in transactions if start <= t.when <= end]
    rolled = roll_up(balances(window))

    lines = [
        f"Income statement, {start.isoformat()} to {end.isoformat()}",
        rule(),
        "Income",
    ]

    income = -rolled.get("Income", Decimal("0"))
    for account in descendants(rolled, "Income"):
        if account == "Income":
            continue
        lines.append(f"  {indent_account(account):<36}{money(-rolled[account])}")
    lines.append(f"  {'Total income':<36}{money(income)}")
    lines.append("")

    lines.append("Expenses")
    expenses = rolled.get("Expenses", Decimal("0"))
    for account in descendants(rolled, "Expenses"):
        if account == "Expenses":
            continue
        lines.append(f"  {indent_account(account):<36}{money(rolled[account])}")
    lines.append(f"  {'Total expenses':<36}{money(expenses)}")
    lines.append("")

    lines.append(rule())
    lines.append(f"{'Surplus':<38}{money(income - expenses)}")
    if income:
        margin = (income - expenses) / income * 100
        lines.append(f"{'Margin':<38}{margin.quantize(Decimal('0.1')):>11}%")
    return lines


def cash_flow(transactions: list[Transaction], account: str) -> list[str]:
    monthly = by_month(transactions, account)
    if not monthly:
        return [f"No movement on {account}."]

    lines = [f"Monthly movement on {account}", rule(46)]
    running = Decimal("0")
    for month in sorted(monthly):
        running += monthly[month]
        bar_width = min(24, int(abs(monthly[month]) / 250))
        bar = ("+" if monthly[month] >= 0 else "-") * bar_width
        lines.append(
            f"{month}  {money(monthly[month])}  {money(running)}  {bar}"
        )
    lines.append(rule(46))
    lines.append(f"{'closing':<8}{money(running, 22)}")
    return lines


def largest_expenses(transactions: list[Transaction], count: int = 8) -> list[str]:
    rows: list[tuple[Decimal, date, str, str]] = []
    for transaction in transactions:
        for posting in transaction.postings:
            if posting.root == "Expenses" and posting.amount > 0:
                rows.append(
                    (posting.amount, transaction.when, transaction.description,
                     posting.account)
                )
    rows.sort(reverse=True)

    lines = [f"Largest {min(count, len(rows))} expense postings", rule()]
    for amount, when, description, account in rows[:count]:
        lines.append(
            f"{when.isoformat()}  {description[:24]:<24}{money(amount)}"
        )
        lines.append(f"{'':12}{account}")
    return lines


# ------------------------------------------------------------------- built-in

EXAMPLE = """\
; A fictional household ledger. Every figure is invented.

2027-01-01 * Opening balances
    Assets:Bank:Current            4200.00 GBP
    Assets:Bank:Savings            9150.00 GBP
    Liabilities:Card:Visa          -840.00 GBP
    Equity:Opening

2027-01-03 * Salary, January            ; income, monthly
    Assets:Bank:Current            3180.00 GBP
    Income:Salary

2027-01-05 * Rent for January
    Expenses:Housing:Rent          1450.00 GBP
    Assets:Bank:Current

2027-01-08 * Weekly shop
    Expenses:Food:Groceries          96.40 GBP
    Liabilities:Card:Visa

2027-01-12 * Electricity and gas
    Expenses:Housing:Utilities      186.40 GBP
    Assets:Bank:Current

2027-01-15 * Weekly shop
    Expenses:Food:Groceries         104.15 GBP
    Liabilities:Card:Visa

2027-01-20 * Transfer to savings
    Assets:Bank:Savings             400.00 GBP
    Assets:Bank:Current

2027-01-22 * Card payment
    Liabilities:Card:Visa           300.00 GBP
    Assets:Bank:Current

2027-01-28 * Train season ticket
    Expenses:Transport:Rail         278.00 GBP
    Assets:Bank:Current

2027-02-03 * Salary, February
    Assets:Bank:Current            3180.00 GBP
    Income:Salary

2027-02-05 * Rent for February
    Expenses:Housing:Rent          1450.00 GBP
    Assets:Bank:Current

2027-02-09 * Weekly shop
    Expenses:Food:Groceries         112.80 GBP
    Liabilities:Card:Visa

2027-02-11 * Boiler repair            ; unplanned
    Expenses:Housing:Maintenance    340.00 GBP
    Assets:Bank:Savings

2027-02-14 * Dinner out
    Expenses:Food:Eating out         64.50 GBP
    Liabilities:Card:Visa

2027-02-18 * Electricity and gas
    Expenses:Housing:Utilities      201.75 GBP
    Assets:Bank:Current

2027-02-20 * Transfer to savings
    Assets:Bank:Savings             400.00 GBP
    Assets:Bank:Current

2027-02-24 * Card payment
    Liabilities:Card:Visa           250.00 GBP
    Assets:Bank:Current

2027-03-03 * Salary, March
    Assets:Bank:Current            3180.00 GBP
    Income:Salary

2027-03-04 * Freelance invoice paid
    Assets:Bank:Current             720.00 GBP
    Income:Freelance

2027-03-05 * Rent for March
    Expenses:Housing:Rent          1450.00 GBP
    Assets:Bank:Current

2027-03-10 * Weekly shop
    Expenses:Food:Groceries          88.20 GBP
    Liabilities:Card:Visa

2027-03-16 * Electricity and gas
    Expenses:Housing:Utilities      172.30 GBP
    Assets:Bank:Current

2027-03-20 * Transfer to savings
    Assets:Bank:Savings             400.00 GBP
    Assets:Bank:Current

2027-03-25 * Card payment
    Liabilities:Card:Visa           200.00 GBP
    Assets:Bank:Current
"""


REPORTS = ("trial-balance", "balance-sheet", "income", "cash-flow", "largest", "all")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("path", nargs="?", help="ledger file; omit for the example")
    parser.add_argument(
        "--report", choices=REPORTS, default="all", help="which report to print"
    )
    parser.add_argument(
        "--account", default="Assets:Bank:Current", help="account for --report cash-flow"
    )
    arguments = parser.parse_args(argv)

    if arguments.path:
        try:
            with open(arguments.path, encoding="utf-8") as handle:
                source = handle.read()
        except OSError as error:
            print(f"cannot read {arguments.path}: {error}", file=sys.stderr)
            return 2
    else:
        source = EXAMPLE

    try:
        transactions = parse(source.splitlines())
    except LedgerError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if not transactions:
        print("the ledger is empty")
        return 0

    start = min(t.when for t in transactions)
    end = max(t.when for t in transactions)

    blocks: list[list[str]] = []
    if arguments.report in ("trial-balance", "all"):
        blocks.append(trial_balance(transactions))
    if arguments.report in ("balance-sheet", "all"):
        blocks.append(balance_sheet(transactions, end))
    if arguments.report in ("income", "all"):
        blocks.append(income_statement(transactions, start, end))
    if arguments.report in ("cash-flow", "all"):
        blocks.append(cash_flow(transactions, arguments.account))
    if arguments.report in ("largest", "all"):
        blocks.append(largest_expenses(transactions))

    print(f"{len(transactions)} transactions, {start} to {end}\n")
    for index, block in enumerate(blocks):
        if index:
            print()
        print("\n".join(block))

    return 0


if __name__ == "__main__":
    sys.exit(main())
