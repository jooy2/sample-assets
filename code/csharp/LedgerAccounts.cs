// LedgerAccounts.cs — a double-entry ledger: posting, balancing, and reporting.
//
// Records with value equality and `with`, primary constructors, required and
// init-only members, nullable reference types, pattern matching (property,
// relational, list, and logical patterns), switch expressions, LINQ, custom
// operators, IComparable, IParsable, extension methods, local functions, and
// spans for parsing without allocating.
//
//   dotnet run LedgerAccounts.cs      # .NET 10 file-based apps
//   csc LedgerAccounts.cs && ./LedgerAccounts
//
// Requires C# 12 / .NET 8 or later. Every account, transaction, and figure
// below is invented.

#nullable enable

using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Globalization;
using System.Linq;
using System.Text;

namespace SampleAssets.Accounting;

// ------------------------------------------------------------------- money

/// <summary>
/// An amount in minor units. A readonly record struct, so it compares by
/// value, costs nothing to copy, and cannot be mutated by accident.
/// </summary>
public readonly record struct Money(long Minor, string Currency = "GBP")
    : IComparable<Money>, IParsable<Money>
{
    public static Money Zero(string currency = "GBP") => new(0, currency);

    public static Money FromMajor(decimal amount, string currency = "GBP") =>
        new((long)decimal.Round(amount * 100m, 0, MidpointRounding.AwayFromZero), currency);

    public decimal Major => Minor / 100m;

    public bool IsZero => Minor == 0;

    public bool IsDebit => Minor > 0;

    public Money Abs() => this with { Minor = Math.Abs(Minor) };

    public static Money operator +(Money left, Money right)
    {
        SameCurrency(left, right);
        return left with { Minor = left.Minor + right.Minor };
    }

    public static Money operator -(Money left, Money right)
    {
        SameCurrency(left, right);
        return left with { Minor = left.Minor - right.Minor };
    }

    public static Money operator -(Money value) => value with { Minor = -value.Minor };

    public static Money operator *(Money value, decimal factor) =>
        value with { Minor = (long)decimal.Round(value.Minor * factor, 0, MidpointRounding.AwayFromZero) };

    public static bool operator <(Money left, Money right) => left.CompareTo(right) < 0;
    public static bool operator >(Money left, Money right) => left.CompareTo(right) > 0;
    public static bool operator <=(Money left, Money right) => left.CompareTo(right) <= 0;
    public static bool operator >=(Money left, Money right) => left.CompareTo(right) >= 0;

    public int CompareTo(Money other)
    {
        SameCurrency(this, other);
        return Minor.CompareTo(other.Minor);
    }

    /// <summary>
    /// Split evenly, giving the odd pennies to the earliest parts so the
    /// pieces always add back up to the whole.
    /// </summary>
    public ImmutableArray<Money> Allocate(int parts)
    {
        if (parts < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(parts), parts, "at least one part is needed");
        }

        var each = Math.DivRem(Minor, parts, out var remainder);
        var builder = ImmutableArray.CreateBuilder<Money>(parts);

        for (var index = 0; index < parts; index++)
        {
            var extra = index < Math.Abs(remainder) ? Math.Sign(remainder) : 0;
            builder.Add(this with { Minor = each + extra });
        }
        return builder.ToImmutable();
    }

    public static Money Parse(string text, IFormatProvider? provider = null) =>
        TryParse(text, provider, out var value)
            ? value
            : throw new FormatException($"\"{text}\" is not an amount");

    /// <summary>
    /// Parse "1,234.56" or "-12.30" without allocating a substring per piece.
    /// </summary>
    public static bool TryParse(string? text, IFormatProvider? provider, out Money result)
    {
        result = Zero();
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        ReadOnlySpan<char> span = text.AsSpan().Trim();
        var negative = false;

        // Accountants write a negative as (12.30); everyone else writes -12.30.
        if (span.Length >= 2 && span[0] == '(' && span[^1] == ')')
        {
            negative = true;
            span = span[1..^1];
        }
        else if (span.Length >= 1 && span[0] == '-')
        {
            negative = true;
            span = span[1..];
        }

        Span<char> digits = stackalloc char[span.Length];
        var length = 0;
        foreach (var character in span)
        {
            if (character is >= '0' and <= '9' or '.')
            {
                digits[length++] = character;
            }
            else if (character is not (',' or ' ' or '£' or '$'))
            {
                return false;
            }
        }

        if (length == 0 || !decimal.TryParse(
                digits[..length],
                NumberStyles.AllowDecimalPoint,
                provider ?? CultureInfo.InvariantCulture,
                out var amount))
        {
            return false;
        }

        result = FromMajor(negative ? -amount : amount);
        return true;
    }

    public override string ToString() => ToString(Currency);

    public string ToString(string currency)
    {
        var symbol = currency switch
        {
            "GBP" => "£",
            "EUR" => "€",
            "USD" => "$",
            _ => currency + " ",
        };
        var absolute = Math.Abs(Minor);
        var body = $"{symbol}{absolute / 100:N0}.{absolute % 100:00}";
        return Minor < 0 ? $"({body})" : body;
    }

    private static void SameCurrency(Money left, Money right)
    {
        if (!string.Equals(left.Currency, right.Currency, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"cannot combine {left.Currency} with {right.Currency}");
        }
    }
}

// ---------------------------------------------------------------- accounts

public enum AccountKind
{
    Asset,
    Liability,
    Equity,
    Income,
    Expense,
}

/// <summary>
/// An account in the chart. A record, so two accounts with the same code are
/// equal without anyone writing Equals.
/// </summary>
public sealed record Account(string Code, string Name, AccountKind Kind, string? Parent = null)
{
    /// <summary>
    /// Whether a positive balance on this account is a debit. Assets and
    /// expenses increase on the debit side; everything else on the credit.
    /// </summary>
    public bool NormallyDebit => Kind is AccountKind.Asset or AccountKind.Expense;

    public string Path => Parent is null ? Code : $"{Parent}:{Code}";

    public override string ToString() => $"{Code} {Name}";
}

/// <summary>One leg of a transaction.</summary>
public readonly record struct Posting(string Account, Money Amount, string? Memo = null)
{
    public bool IsDebit => Amount.Minor > 0;
}

/// <summary>
/// A balanced set of postings. The constructor refuses anything that does not
/// sum to zero, which is the whole discipline of double entry in one place.
/// </summary>
public sealed record Transaction
{
    public required string Reference { get; init; }
    public required DateOnly Date { get; init; }
    public required string Description { get; init; }
    public required ImmutableArray<Posting> Postings { get; init; }
    public ImmutableArray<string> Tags { get; init; } = ImmutableArray<string>.Empty;

    public Money Total => Postings.Aggregate(Money.Zero(), (running, posting) => running + posting.Amount);

    public bool Balances => Total.IsZero;

    public IEnumerable<Posting> Debits => Postings.Where(posting => posting.IsDebit);

    public IEnumerable<Posting> Credits => Postings.Where(posting => !posting.IsDebit);

    /// <summary>The size of the transaction: the total on either side.</summary>
    public Money Magnitude =>
        Debits.Aggregate(Money.Zero(), (running, posting) => running + posting.Amount);

    public static Transaction Create(
        string reference,
        DateOnly date,
        string description,
        params Posting[] postings)
    {
        var transaction = new Transaction
        {
            Reference = reference,
            Date = date,
            Description = description,
            Postings = [.. postings],
        };

        if (!transaction.Balances)
        {
            throw new UnbalancedTransactionException(reference, transaction.Total);
        }
        return transaction;
    }

    /// <summary>
    /// Build a two-legged transaction, working out the second leg. The common
    /// case, and the one where a hand-written second posting goes wrong.
    /// </summary>
    public static Transaction Simple(
        string reference,
        DateOnly date,
        string description,
        string debit,
        string credit,
        Money amount) =>
        Create(reference, date, description,
            new Posting(debit, amount),
            new Posting(credit, -amount));
}

public sealed class UnbalancedTransactionException(string reference, Money difference)
    : InvalidOperationException($"{reference} does not balance; it is out by {difference}")
{
    public string Reference { get; } = reference;
    public Money Difference { get; } = difference;
}

// ------------------------------------------------------------------ ledger

public sealed class Ledger
{
    private readonly Dictionary<string, Account> _accounts = new(StringComparer.Ordinal);
    private readonly List<Transaction> _transactions = [];

    public IReadOnlyCollection<Account> Accounts => _accounts.Values;

    public IReadOnlyList<Transaction> Transactions => _transactions;

    public Ledger Add(params Account[] accounts)
    {
        foreach (var account in accounts)
        {
            if (!_accounts.TryAdd(account.Code, account))
            {
                throw new InvalidOperationException($"{account.Code} is already in the chart");
            }
        }
        return this;
    }

    public Ledger Post(params Transaction[] transactions)
    {
        foreach (var transaction in transactions)
        {
            var unknown = transaction.Postings
                .Select(posting => posting.Account)
                .Where(code => !_accounts.ContainsKey(code))
                .Distinct()
                .ToList();

            if (unknown.Count > 0)
            {
                throw new InvalidOperationException(
                    $"{transaction.Reference} posts to unknown account(s): {string.Join(", ", unknown)}");
            }
            _transactions.Add(transaction);
        }
        return this;
    }

    public Account this[string code] =>
        _accounts.TryGetValue(code, out var account)
            ? account
            : throw new KeyNotFoundException($"no account {code}");

    /// <summary>Balance of one account, as at a date.</summary>
    public Money BalanceOf(string code, DateOnly? asAt = null) =>
        _transactions
            .Where(transaction => asAt is null || transaction.Date <= asAt)
            .SelectMany(transaction => transaction.Postings)
            .Where(posting => string.Equals(posting.Account, code, StringComparison.Ordinal))
            .Aggregate(Money.Zero(), (running, posting) => running + posting.Amount);

    /// <summary>Every account with a non-zero balance, in code order.</summary>
    public IEnumerable<(Account Account, Money Balance)> Balances(DateOnly? asAt = null) =>
        _accounts.Values
            .Select(account => (Account: account, Balance: BalanceOf(account.Code, asAt)))
            .Where(pair => !pair.Balance.IsZero)
            .OrderBy(pair => pair.Account.Code, StringComparer.Ordinal);

    /// <summary>Totals by account kind, which is what the reports are built on.</summary>
    public IReadOnlyDictionary<AccountKind, Money> ByKind(DateOnly? asAt = null) =>
        Balances(asAt)
            .GroupBy(pair => pair.Account.Kind)
            .ToDictionary(
                group => group.Key,
                group => group.Aggregate(Money.Zero(), (running, pair) => running + pair.Balance));

    /// <summary>Everything that touched one account, oldest first.</summary>
    public IEnumerable<(Transaction Transaction, Posting Posting, Money Running)> Statement(string code)
    {
        var running = Money.Zero();
        foreach (var transaction in _transactions.OrderBy(item => item.Date).ThenBy(item => item.Reference, StringComparer.Ordinal))
        {
            foreach (var posting in transaction.Postings.Where(
                         posting => string.Equals(posting.Account, code, StringComparison.Ordinal)))
            {
                running += posting.Amount;
                yield return (transaction, posting, running);
            }
        }
    }

    /// <summary>
    /// Everything wrong with the ledger, as a list rather than an exception,
    /// so a caller can show all of it at once.
    /// </summary>
    public IReadOnlyList<string> Problems()
    {
        var problems = new List<string>();

        foreach (var transaction in _transactions.Where(transaction => !transaction.Balances))
        {
            problems.Add($"{transaction.Reference} is out by {transaction.Total}");
        }

        var duplicates = _transactions
            .GroupBy(transaction => transaction.Reference, StringComparer.Ordinal)
            .Where(group => group.Count() > 1);

        foreach (var group in duplicates)
        {
            problems.Add($"{group.Key} appears {group.Count()} times");
        }

        var kinds = ByKind();
        var assets = kinds.GetValueOrDefault(AccountKind.Asset, Money.Zero());
        var liabilities = kinds.GetValueOrDefault(AccountKind.Liability, Money.Zero());
        var equity = kinds.GetValueOrDefault(AccountKind.Equity, Money.Zero());
        var income = kinds.GetValueOrDefault(AccountKind.Income, Money.Zero());
        var expenses = kinds.GetValueOrDefault(AccountKind.Expense, Money.Zero());

        var difference = assets + liabilities + equity + income + expenses;
        if (!difference.IsZero)
        {
            problems.Add($"the ledger as a whole is out by {difference}");
        }

        return problems;
    }
}

// ----------------------------------------------------------------- reports

public static class Reports
{
    private const int Width = 62;

    public static string TrialBalance(Ledger ledger, DateOnly asAt)
    {
        var output = new StringBuilder();
        output.AppendLine($"Trial balance as at {asAt:d MMMM yyyy}");
        output.AppendLine(new string('-', Width));
        output.AppendLine($"{"Account",-34}{"Debit",14}{"Credit",14}");

        var debits = Money.Zero();
        var credits = Money.Zero();

        foreach (var (account, balance) in ledger.Balances(asAt))
        {
            if (balance.IsDebit)
            {
                debits += balance;
                output.AppendLine($"{account,-34}{balance.ToString(),14}{string.Empty,14}");
            }
            else
            {
                credits += -balance;
                output.AppendLine($"{account,-34}{string.Empty,14}{(-balance).ToString(),14}");
            }
        }

        output.AppendLine(new string('-', Width));
        output.AppendLine($"{string.Empty,-34}{debits.ToString(),14}{credits.ToString(),14}");
        output.Append(debits == credits ? "In balance." : $"OUT BY {debits - credits}");
        return output.ToString();
    }

    public static string IncomeStatement(Ledger ledger, DateOnly from, DateOnly to)
    {
        var income = Money.Zero();
        var expenses = Money.Zero();
        var lines = new List<string>();

        var inPeriod = ledger.Transactions.Where(t => t.Date >= from && t.Date <= to).ToList();

        var byAccount = inPeriod
            .SelectMany(transaction => transaction.Postings)
            .GroupBy(posting => posting.Account, StringComparer.Ordinal)
            .Select(group => (
                Account: ledger[group.Key],
                Balance: group.Aggregate(Money.Zero(), (running, posting) => running + posting.Amount)))
            .Where(pair => pair.Account.Kind is AccountKind.Income or AccountKind.Expense)
            .OrderBy(pair => pair.Account.Kind)
            .ThenBy(pair => pair.Account.Code, StringComparer.Ordinal);

        foreach (var (account, balance) in byAccount)
        {
            // Income sits on the credit side, so its balance is negative and
            // is shown the other way up.
            var shown = account.Kind is AccountKind.Income ? -balance : balance;
            if (shown.IsZero)
            {
                continue;
            }

            lines.Add($"  {account,-40}{shown.ToString(),16}");
            if (account.Kind is AccountKind.Income)
            {
                income += shown;
            }
            else
            {
                expenses += shown;
            }
        }

        var output = new StringBuilder();
        output.AppendLine($"Income statement, {from:d MMM yyyy} to {to:d MMM yyyy}");
        output.AppendLine(new string('-', Width));
        foreach (var line in lines)
        {
            output.AppendLine(line);
        }
        output.AppendLine(new string('-', Width));
        output.AppendLine($"  {"Income",-40}{income.ToString(),16}");
        output.AppendLine($"  {"Expenses",-40}{expenses.ToString(),16}");
        output.Append($"  {"Surplus",-40}{(income - expenses).ToString(),16}");

        return output.ToString();
    }

    /// <summary>Describe a balance in words, using pattern matching.</summary>
    public static string Describe(Account account, Money balance) => (account, balance) switch
    {
        ({ Kind: AccountKind.Asset }, { Minor: 0 }) => "an empty asset account",
        ({ Kind: AccountKind.Asset }, { Minor: < 0 }) => "an asset in credit, which wants explaining",
        ({ Kind: AccountKind.Asset }, var amount) when amount.Minor > 1_000_00 => "a substantial asset",
        ({ Kind: AccountKind.Asset }, _) => "an asset",
        ({ Kind: AccountKind.Liability }, { Minor: > 0 }) => "a liability in debit, which is unusual",
        ({ Kind: AccountKind.Liability }, _) => "money owed",
        ({ Kind: AccountKind.Income }, _) => "income earned",
        ({ Kind: AccountKind.Expense }, { Minor: > 0 }) => "money spent",
        ({ Kind: AccountKind.Expense }, _) => "an expense reversed",
        ({ Kind: AccountKind.Equity }, _) => "capital",
        _ => "something unaccounted for",
    };
}

// ------------------------------------------------------------- extensions

public static class LedgerExtensions
{
    /// <summary>Sum a sequence of money, which LINQ cannot do on its own.</summary>
    public static Money Sum<T>(this IEnumerable<T> source, Func<T, Money> select) =>
        source.Aggregate(Money.Zero(), (running, item) => running + select(item));

    /// <summary>The largest few by some measure.</summary>
    public static IEnumerable<T> Largest<T>(this IEnumerable<T> source, Func<T, Money> by, int count) =>
        source.OrderByDescending(item => by(item).Minor).Take(count);
}

// ---------------------------------------------------------------- the demo

public static class Program
{
    private static Ledger BuildLedger()
    {
        var ledger = new Ledger().Add(
            new Account("1000", "Bank: current", AccountKind.Asset),
            new Account("1010", "Bank: reserve", AccountKind.Asset),
            new Account("1200", "Debtors", AccountKind.Asset),
            new Account("2000", "Creditors", AccountKind.Liability),
            new Account("2100", "Deferred fares", AccountKind.Liability),
            new Account("3000", "Members' capital", AccountKind.Equity),
            new Account("4000", "Fare income", AccountKind.Income),
            new Account("4100", "Charter income", AccountKind.Income),
            new Account("5000", "Crew wages", AccountKind.Expense),
            new Account("5100", "Fuel", AccountKind.Expense),
            new Account("5200", "Maintenance", AccountKind.Expense),
            new Account("5300", "Terminal costs", AccountKind.Expense));

        var april = new DateOnly(2027, 4, 1);

        return ledger.Post(
            Transaction.Simple("J-0001", april, "Opening capital",
                debit: "1000", credit: "3000", Money.FromMajor(120_000m)),
            Transaction.Simple("J-0002", april.AddDays(4), "Fares, week 1",
                debit: "1000", credit: "4000", Money.FromMajor(41_820m)),
            Transaction.Simple("J-0003", april.AddDays(11), "Fares, week 2",
                debit: "1000", credit: "4000", Money.FromMajor(38_640m)),
            Transaction.Create("J-0004", april.AddDays(14), "Crew wages, April",
                new Posting("5000", Money.FromMajor(28_400m), "gross"),
                new Posting("1000", Money.FromMajor(-22_100m), "net paid"),
                new Posting("2000", Money.FromMajor(-6_300m), "deductions owed")),
            Transaction.Simple("J-0005", april.AddDays(18), "Fuel",
                debit: "5100", credit: "1000", Money.FromMajor(11_240m)),
            Transaction.Simple("J-0006", april.AddDays(21), "Charter, school trip",
                debit: "1200", credit: "4100", Money.FromMajor(3_400m)),
            Transaction.Simple("J-0007", april.AddDays(25), "Gearbox replacement",
                debit: "5200", credit: "2000", Money.FromMajor(14_880m)),
            Transaction.Simple("J-0008", april.AddDays(28), "Transfer to reserve",
                debit: "1010", credit: "1000", Money.FromMajor(25_000m)),
            Transaction.Create("J-0009", april.AddDays(29), "Season tickets sold",
                new Posting("1000", Money.FromMajor(18_600m)),
                new Posting("4000", Money.FromMajor(-6_200m), "recognised"),
                new Posting("2100", Money.FromMajor(-12_400m), "deferred")),
            Transaction.Simple("J-0010", april.AddDays(30), "Terminal rates",
                debit: "5300", credit: "1000", Money.FromMajor(4_960m)));
    }

    private static void Heading(string title)
    {
        Console.WriteLine();
        Console.WriteLine($"--- {title} ---");
    }

    public static void Main()
    {
        Console.OutputEncoding = Encoding.UTF8;

        var ledger = BuildLedger();
        var asAt = new DateOnly(2027, 4, 30);

        Heading("the ledger");
        Console.WriteLine($"  {ledger.Accounts.Count} account(s), {ledger.Transactions.Count} transaction(s)");
        Console.WriteLine($"  every transaction balances: {ledger.Transactions.All(t => t.Balances)}");
        Console.WriteLine($"  problems found: {ledger.Problems().Count}");

        Heading("trial balance");
        Console.WriteLine(Reports.TrialBalance(ledger, asAt));

        Heading("income statement");
        Console.WriteLine(Reports.IncomeStatement(ledger, new DateOnly(2027, 4, 1), asAt));

        Heading("a statement for the current account");
        foreach (var (transaction, posting, running) in ledger.Statement("1000"))
        {
            Console.WriteLine(
                $"  {transaction.Date:dd MMM}  {transaction.Reference}  " +
                $"{transaction.Description,-28} {posting.Amount.ToString(),14} {running.ToString(),14}");
        }

        Heading("balances described");
        foreach (var (account, balance) in ledger.Balances(asAt).Take(6))
        {
            Console.WriteLine($"  {account,-30}{balance.ToString(),14}  {Reports.Describe(account, balance)}");
        }

        Heading("the largest expenses");
        foreach (var (account, balance) in ledger.Balances(asAt)
                     .Where(pair => pair.Account.Kind is AccountKind.Expense)
                     .Largest(pair => pair.Balance, 3))
        {
            Console.WriteLine($"  {account,-30}{balance.ToString(),14}");
        }

        Heading("records compare by value");
        var one = new Account("9999", "Test", AccountKind.Asset);
        var two = new Account("9999", "Test", AccountKind.Asset);
        Console.WriteLine($"  equal: {one == two}, same hash: {one.GetHashCode() == two.GetHashCode()}");
        var renamed = one with { Name = "Renamed" };
        Console.WriteLine($"  `with` made a copy: {renamed.Name}, and left the original as {one.Name}");

        Heading("a transaction that does not balance is refused");
        try
        {
            Transaction.Create("J-BAD", asAt, "Two legs that disagree",
                new Posting("1000", Money.FromMajor(100m)),
                new Posting("4000", Money.FromMajor(-90m)));
        }
        catch (UnbalancedTransactionException error)
        {
            Console.WriteLine($"  {error.Message}");
            Console.WriteLine($"  the difference is available as a value: {error.Difference}");
        }

        Heading("posting to an account that is not in the chart");
        try
        {
            ledger.Post(Transaction.Simple("J-BAD2", asAt, "Nowhere",
                debit: "9998", credit: "1000", Money.FromMajor(1m)));
        }
        catch (InvalidOperationException error)
        {
            Console.WriteLine($"  {error.Message}");
        }

        Heading("allocation never loses a penny");
        foreach (var parts in new[] { 3, 7, 11 })
        {
            var pieces = Money.FromMajor(100m).Allocate(parts);
            var total = pieces.Sum(piece => piece);
            Console.WriteLine(
                $"  £100.00 into {parts,2}: {string.Join(" ", pieces.Take(3).Select(p => p.ToString()))}" +
                $" ... = {total}");
        }

        Heading("parsing amounts");
        foreach (var candidate in new[] { "1,234.56", "-12.30", "(45.00)", "£9.99", "", "twelve" })
        {
            var shown = string.IsNullOrEmpty(candidate) ? "(empty)" : candidate;
            Console.WriteLine(Money.TryParse(candidate, CultureInfo.InvariantCulture, out var parsed)
                ? $"  {shown,-12} -> {parsed} ({parsed.Minor} minor units)"
                : $"  {shown,-12} -> rejected");
        }

        Heading("list patterns");
        foreach (var transaction in ledger.Transactions.Take(4))
        {
            var shape = transaction.Postings switch
            {
                [] => "empty, which cannot happen",
                [var only] => $"a single posting of {only.Amount}, which cannot balance",
                [var debit, var credit] => $"two legs: {debit.Amount} against {credit.Amount}",
                [_, _, _] => "three legs",
                _ => $"{transaction.Postings.Length} legs",
            };
            Console.WriteLine($"  {transaction.Reference}: {shape}");
        }

        Heading("relational and logical patterns");
        foreach (var (account, balance) in ledger.Balances(asAt).Take(5))
        {
            var size = balance.Abs().Minor switch
            {
                0 => "nothing",
                > 0 and < 1_000_00 => "under a thousand",
                >= 1_000_00 and < 50_000_00 => "thousands",
                _ => "tens of thousands",
            };
            Console.WriteLine($"  {account.Code}  {balance.ToString(),14}  {size}");
        }

        Heading("money arithmetic");
        var fare = Money.FromMajor(12.50m);
        Console.WriteLine($"  one fare      {fare}");
        Console.WriteLine($"  four fares    {fare * 4}");
        Console.WriteLine($"  less a note   {fare * 4 - Money.FromMajor(20m)}");
        Console.WriteLine($"  negated       {-fare}");
        Console.WriteLine($"  compared      {fare} < {fare * 2}: {fare < fare * 2}");

        Heading("mixing currencies is refused");
        try
        {
            _ = Money.FromMajor(1m, "GBP") + Money.FromMajor(1m, "EUR");
        }
        catch (InvalidOperationException error)
        {
            Console.WriteLine($"  {error.Message}");
        }
    }
}
