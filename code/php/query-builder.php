<?php

declare(strict_types=1);

/**
 * query-builder.php — a fluent SQL builder that always parameterises.
 *
 * Interfaces, abstract classes, traits, enums, readonly value objects, static
 * factory methods, __call for dynamic where helpers, IteratorAggregate,
 * ArrayAccess, Countable, generators, and a grammar object so the same query
 * renders for more than one dialect.
 *
 *   php query-builder.php
 *
 * The point of the exercise: values never reach the SQL string. Every value
 * given to the builder becomes a placeholder and a binding, so a query cannot
 * be assembled by concatenation even by accident.
 *
 * Requires PHP 8.2 or later (readonly classes). Nothing here connects to a
 * database; the schema
 * and the data are invented.
 */

// -------------------------------------------------------------------- enums

enum Direction: string
{
    case Asc = 'ASC';
    case Desc = 'DESC';
}

enum JoinKind: string
{
    case Inner = 'INNER JOIN';
    case Left = 'LEFT JOIN';
    case Right = 'RIGHT JOIN';
    case Cross = 'CROSS JOIN';
}

/**
 * How two conditions are joined. Named AndAlso/OrElse rather than And/Or so
 * the cases are never mistaken for the language's own operators.
 */
enum Joiner: string
{
    case AndAlso = 'AND';
    case OrElse = 'OR';
}

enum Dialect
{
    case MySQL;
    case PostgreSQL;
    case SQLite;
}

// ------------------------------------------------------------------ grammar

/**
 * How a dialect spells the things dialects disagree about: identifier quoting,
 * placeholders, LIMIT/OFFSET, and string concatenation.
 */
abstract class Grammar
{
    abstract public function quote(string $identifier): string;

    abstract public function placeholder(int $index): string;

    abstract public function limitClause(?int $limit, ?int $offset): string;

    public static function for(Dialect $dialect): self
    {
        return match ($dialect) {
            Dialect::MySQL => new MySqlGrammar(),
            Dialect::PostgreSQL => new PostgresGrammar(),
            Dialect::SQLite => new SqliteGrammar(),
        };
    }

    /**
     * Quote a possibly-qualified name: "routes.code" becomes two quoted
     * parts, and "*" is left alone.
     */
    /**
     * Quote a name that must be an identifier: a table, or a join target.
     * Unlike qualify(), nothing is passed through untouched, so a name with a
     * quote in it is escaped rather than trusted.
     */
    public function qualifyName(string $name): string
    {
        return implode('.', array_map(
            fn (string $part): string => $this->quote($part),
            explode('.', $name),
        ));
    }

    public function qualify(string $name): string
    {
        if ($name === '*') {
            return '*';
        }

        // An expression rather than a column: leave it entirely alone.
        if (preg_match('/^[A-Za-z_][A-Za-z0-9_.]*$/', $name) !== 1) {
            return $name;
        }

        return implode('.', array_map(
            fn (string $part): string => $part === '*' ? '*' : $this->quote($part),
            explode('.', $name),
        ));
    }
}

final class MySqlGrammar extends Grammar
{
    public function quote(string $identifier): string
    {
        return '`' . str_replace('`', '``', $identifier) . '`';
    }

    public function placeholder(int $index): string
    {
        return '?';
    }

    public function limitClause(?int $limit, ?int $offset): string
    {
        if ($limit === null && $offset === null) {
            return '';
        }
        // MySQL cannot take OFFSET without LIMIT, so a very large limit
        // stands in when only an offset was asked for.
        $limit ??= PHP_INT_MAX;
        return $offset === null ? "LIMIT {$limit}" : "LIMIT {$limit} OFFSET {$offset}";
    }
}

final class PostgresGrammar extends Grammar
{
    public function quote(string $identifier): string
    {
        return '"' . str_replace('"', '""', $identifier) . '"';
    }

    public function placeholder(int $index): string
    {
        return '$' . $index;
    }

    public function limitClause(?int $limit, ?int $offset): string
    {
        $parts = [];
        if ($limit !== null) {
            $parts[] = "LIMIT {$limit}";
        }
        if ($offset !== null) {
            $parts[] = "OFFSET {$offset}";
        }
        return implode(' ', $parts);
    }
}

final class SqliteGrammar extends Grammar
{
    public function quote(string $identifier): string
    {
        return '"' . str_replace('"', '""', $identifier) . '"';
    }

    public function placeholder(int $index): string
    {
        return '?';
    }

    public function limitClause(?int $limit, ?int $offset): string
    {
        if ($limit === null && $offset === null) {
            return '';
        }
        $limit ??= -1;
        return $offset === null ? "LIMIT {$limit}" : "LIMIT {$limit} OFFSET {$offset}";
    }
}

// ------------------------------------------------------------------ bindings

/**
 * The bindings collected while a query is built, in the order the
 * placeholders appear.
 */
final class Bindings implements Countable, IteratorAggregate, ArrayAccess
{
    /** @var list<mixed> */
    private array $values = [];

    public function add(mixed $value): int
    {
        $this->values[] = $value;
        return count($this->values); // one-based, which is what $1 wants
    }

    /** @param iterable<mixed> $values */
    public function addMany(iterable $values): array
    {
        $indexes = [];
        foreach ($values as $value) {
            $indexes[] = $this->add($value);
        }
        return $indexes;
    }

    /** @return list<mixed> */
    public function all(): array
    {
        return $this->values;
    }

    public function count(): int
    {
        return count($this->values);
    }

    public function getIterator(): Traversable
    {
        return new ArrayIterator($this->values);
    }

    public function offsetExists(mixed $offset): bool
    {
        return isset($this->values[$offset]);
    }

    public function offsetGet(mixed $offset): mixed
    {
        return $this->values[$offset] ?? null;
    }

    public function offsetSet(mixed $offset, mixed $value): void
    {
        throw new LogicException('bindings are append-only; use add()');
    }

    public function offsetUnset(mixed $offset): void
    {
        throw new LogicException('bindings are append-only');
    }

    /** For display only. Never build a query this way. */
    public function describe(): string
    {
        return implode(', ', array_map(
            static fn (mixed $value): string => match (true) {
                $value === null => 'NULL',
                is_bool($value) => $value ? 'true' : 'false',
                is_int($value), is_float($value) => (string) $value,
                default => "'" . (string) $value . "'",
            },
            $this->values,
        ));
    }
}

// ---------------------------------------------------------------- conditions

interface Condition
{
    public function toSql(Grammar $grammar, Bindings $bindings): string;
}

final readonly class Comparison implements Condition
{
    private const OPERATORS = ['=', '<>', '!=', '<', '<=', '>', '>=', 'LIKE', 'NOT LIKE'];

    public function __construct(
        private string $column,
        private string $operator,
        private mixed $value,
    ) {
        if (!in_array(strtoupper($operator), self::OPERATORS, true)) {
            throw new InvalidArgumentException("unsupported operator: {$operator}");
        }
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        $index = $bindings->add($this->value);
        return sprintf(
            '%s %s %s',
            $grammar->qualify($this->column),
            strtoupper($this->operator),
            $grammar->placeholder($index),
        );
    }
}

final readonly class InList implements Condition
{
    /** @param list<mixed> $values */
    public function __construct(
        private string $column,
        private array $values,
        private bool $negated = false,
    ) {
        if ($values === []) {
            throw new InvalidArgumentException("{$column}: IN () matches nothing and is never what was meant");
        }
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        $placeholders = array_map(
            static fn (int $index): string => $grammar->placeholder($index),
            $bindings->addMany($this->values),
        );

        return sprintf(
            '%s %sIN (%s)',
            $grammar->qualify($this->column),
            $this->negated ? 'NOT ' : '',
            implode(', ', $placeholders),
        );
    }
}

final readonly class Between implements Condition
{
    public function __construct(
        private string $column,
        private mixed $low,
        private mixed $high,
    ) {
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        $lowIndex = $bindings->add($this->low);
        $highIndex = $bindings->add($this->high);

        return sprintf(
            '%s BETWEEN %s AND %s',
            $grammar->qualify($this->column),
            $grammar->placeholder($lowIndex),
            $grammar->placeholder($highIndex),
        );
    }
}

final readonly class IsNull implements Condition
{
    public function __construct(
        private string $column,
        private bool $negated = false,
    ) {
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        return $grammar->qualify($this->column) . ($this->negated ? ' IS NOT NULL' : ' IS NULL');
    }
}

/** A comparison between two columns, where neither side is a value. */
final readonly class ColumnsMatch implements Condition
{
    public function __construct(
        private string $left,
        private string $operator,
        private string $right,
    ) {
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        return sprintf(
            '%s %s %s',
            $grammar->qualify($this->left),
            $this->operator,
            $grammar->qualify($this->right),
        );
    }
}

final readonly class Exists implements Condition
{
    public function __construct(
        private QueryBuilder $subquery,
        private bool $negated = false,
    ) {
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        return sprintf(
            '%sEXISTS (%s)',
            $this->negated ? 'NOT ' : '',
            $this->subquery->compileInto($grammar, $bindings),
        );
    }
}

/** A group of conditions joined by AND or OR, rendered with brackets. */
final class ConditionGroup implements Condition
{
    /** @var list<array{Joiner, Condition}> */
    private array $parts = [];

    public function __construct(private readonly Joiner $joiner = Joiner::AndAlso)
    {
    }

    public function push(Condition $condition, Joiner $joiner = Joiner::AndAlso): self
    {
        $this->parts[] = [$joiner, $condition];
        return $this;
    }

    public function isEmpty(): bool
    {
        return $this->parts === [];
    }

    public function toSql(Grammar $grammar, Bindings $bindings): string
    {
        $sql = '';
        foreach ($this->parts as $index => [$joiner, $condition]) {
            $sql .= $index === 0 ? '' : " {$joiner->value} ";
            $sql .= $condition->toSql($grammar, $bindings);
        }
        return count($this->parts) > 1 ? "({$sql})" : $sql;
    }
}

// -------------------------------------------------------------------- joins

final readonly class Join
{
    public function __construct(
        public JoinKind $kind,
        public string $table,
        public ?string $alias,
        public ?Condition $on,
    ) {
    }
}

// ------------------------------------------------------------------ builder

/**
 * The builder itself.
 *
 * Every method returns a clone rather than mutating, so a partly-built query
 * can be shared as a starting point without one caller's `where` leaking into
 * another's.
 *
 * @method self whereCode(mixed $value)
 * @method self whereActive(mixed $value)
 */
final class QueryBuilder
{
    /** @var list<string> */
    private array $columns = ['*'];

    private ConditionGroup $conditions;

    /** @var list<Join> */
    private array $joins = [];

    /** @var list<string> */
    private array $groups = [];

    private ?ConditionGroup $having = null;

    /** @var list<array{string, Direction}> */
    private array $orders = [];

    private ?int $limit = null;
    private ?int $offset = null;
    private bool $distinct = false;

    public function __construct(
        private readonly string $table,
        private readonly ?string $alias = null,
    ) {
        $this->conditions = new ConditionGroup();
    }

    public static function from(string $table, ?string $alias = null): self
    {
        return new self($table, $alias);
    }

    /** Clone-on-write, so the builder behaves like a value. */
    private function with(callable $mutate): self
    {
        $copy = clone $this;
        $copy->conditions = clone $this->conditions;
        if ($this->having !== null) {
            $copy->having = clone $this->having;
        }
        $mutate($copy);
        return $copy;
    }

    public function select(string ...$columns): self
    {
        return $this->with(static function (self $query) use ($columns): void {
            $query->columns = $columns === [] ? ['*'] : array_values($columns);
        });
    }

    public function distinct(bool $on = true): self
    {
        return $this->with(static function (self $query) use ($on): void {
            $query->distinct = $on;
        });
    }

    public function where(string $column, string $operator, mixed $value = null): self
    {
        // where('a', 5) is shorthand for where('a', '=', 5).
        if (func_num_args() === 2) {
            $value = $operator;
            $operator = '=';
        }
        return $this->push(new Comparison($column, $operator, $value));
    }

    public function orWhere(string $column, string $operator, mixed $value = null): self
    {
        if (func_num_args() === 2) {
            $value = $operator;
            $operator = '=';
        }
        return $this->push(new Comparison($column, $operator, $value), Joiner::OrElse);
    }

    /** @param list<mixed> $values */
    public function whereIn(string $column, array $values): self
    {
        return $this->push(new InList($column, $values));
    }

    /** @param list<mixed> $values */
    public function whereNotIn(string $column, array $values): self
    {
        return $this->push(new InList($column, $values, negated: true));
    }

    public function whereBetween(string $column, mixed $low, mixed $high): self
    {
        return $this->push(new Between($column, $low, $high));
    }

    public function whereNull(string $column): self
    {
        return $this->push(new IsNull($column));
    }

    public function whereNotNull(string $column): self
    {
        return $this->push(new IsNull($column, negated: true));
    }

    public function whereExists(self $subquery): self
    {
        return $this->push(new Exists($subquery));
    }

    public function whereNotExists(self $subquery): self
    {
        return $this->push(new Exists($subquery, negated: true));
    }

    /** A bracketed group: ->whereGroup(fn ($q) => $q->where(...)->orWhere(...)). */
    public function whereGroup(callable $build, Joiner $joiner = Joiner::AndAlso): self
    {
        $nested = new self($this->table, $this->alias);
        $built = $build($nested);
        $inner = $built instanceof self ? $built : $nested;

        if ($inner->conditions->isEmpty()) {
            return $this;
        }
        return $this->push($inner->conditions, $joiner);
    }

    private function push(Condition $condition, Joiner $joiner = Joiner::AndAlso): self
    {
        return $this->with(static function (self $query) use ($condition, $joiner): void {
            $query->conditions->push($condition, $joiner);
        });
    }

    public function join(
        string $table,
        string $left,
        string $operator,
        string $right,
        JoinKind $kind = JoinKind::Inner,
        ?string $alias = null,
    ): self {
        return $this->with(static function (self $query) use ($table, $left, $operator, $right, $kind, $alias): void {
            $query->joins[] = new Join($kind, $table, $alias, new ColumnsMatch($left, $operator, $right));
        });
    }

    public function leftJoin(string $table, string $left, string $operator, string $right, ?string $alias = null): self
    {
        return $this->join($table, $left, $operator, $right, JoinKind::Left, $alias);
    }

    public function groupBy(string ...$columns): self
    {
        return $this->with(static function (self $query) use ($columns): void {
            $query->groups = [...$query->groups, ...$columns];
        });
    }

    public function having(string $expression, string $operator, mixed $value): self
    {
        return $this->with(static function (self $query) use ($expression, $operator, $value): void {
            $query->having ??= new ConditionGroup();
            $query->having->push(new Comparison($expression, $operator, $value));
        });
    }

    public function orderBy(string $column, Direction $direction = Direction::Asc): self
    {
        return $this->with(static function (self $query) use ($column, $direction): void {
            $query->orders[] = [$column, $direction];
        });
    }

    public function limit(int $rows): self
    {
        if ($rows < 0) {
            throw new InvalidArgumentException('a limit cannot be negative');
        }
        return $this->with(static function (self $query) use ($rows): void {
            $query->limit = $rows;
        });
    }

    public function offset(int $rows): self
    {
        if ($rows < 0) {
            throw new InvalidArgumentException('an offset cannot be negative');
        }
        return $this->with(static function (self $query) use ($rows): void {
            $query->offset = $rows;
        });
    }

    public function page(int $number, int $size): self
    {
        if ($number < 1) {
            throw new InvalidArgumentException('pages are numbered from one');
        }
        return $this->limit($size)->offset(($number - 1) * $size);
    }

    /**
     * whereCode('HRB') and whereActive(true) work without being declared,
     * which is convenient and is also why the class carries @method tags: a
     * reader and an analyser both need telling.
     */
    public function __call(string $name, array $arguments): self
    {
        if (!str_starts_with($name, 'where') || $arguments === []) {
            throw new BadMethodCallException("no method {$name} on " . self::class);
        }

        $column = strtolower(preg_replace('/(?<!^)[A-Z]/', '_$0', substr($name, 5)) ?? '');
        if ($column === '') {
            throw new BadMethodCallException("no method {$name} on " . self::class);
        }

        return $this->where($column, '=', $arguments[0]);
    }

    // ---------------------------------------------------------- compiling

    /**
     * Compile into an existing binding list, which is what lets a subquery
     * number its placeholders after its parent's.
     */
    public function compileInto(Grammar $grammar, Bindings $bindings): string
    {
        $parts = [];

        $parts[] = 'SELECT' . ($this->distinct ? ' DISTINCT' : '');
        $parts[] = implode(', ', array_map(
            fn (string $column): string => $this->compileColumn($grammar, $column),
            $this->columns,
        ));

        $parts[] = 'FROM ' . $grammar->qualifyName($this->table)
            . ($this->alias !== null ? ' AS ' . $grammar->quote($this->alias) : '');

        foreach ($this->joins as $join) {
            $clause = $join->kind->value . ' ' . $grammar->qualifyName($join->table);
            if ($join->alias !== null) {
                $clause .= ' AS ' . $grammar->quote($join->alias);
            }
            if ($join->on !== null && $join->kind !== JoinKind::Cross) {
                $clause .= ' ON ' . $join->on->toSql($grammar, $bindings);
            }
            $parts[] = $clause;
        }

        if (!$this->conditions->isEmpty()) {
            $parts[] = 'WHERE ' . $this->conditions->toSql($grammar, $bindings);
        }

        if ($this->groups !== []) {
            $parts[] = 'GROUP BY ' . implode(', ', array_map(
                static fn (string $column): string => $grammar->qualify($column),
                $this->groups,
            ));
        }

        if ($this->having !== null && !$this->having->isEmpty()) {
            $parts[] = 'HAVING ' . $this->having->toSql($grammar, $bindings);
        }

        if ($this->orders !== []) {
            $parts[] = 'ORDER BY ' . implode(', ', array_map(
                static fn (array $order): string => $grammar->qualify($order[0]) . ' ' . $order[1]->value,
                $this->orders,
            ));
        }

        $limit = $grammar->limitClause($this->limit, $this->offset);
        if ($limit !== '') {
            $parts[] = $limit;
        }

        // SELECT and the column list belong on one line.
        $head = array_shift($parts) . ' ' . array_shift($parts);
        return implode(' ', [$head, ...$parts]);
    }

    private function compileColumn(Grammar $grammar, string $column): string
    {
        // "count(*) AS n" and "routes.code AS code" both keep their alias.
        if (preg_match('/^(.*?)\s+AS\s+([A-Za-z_][A-Za-z0-9_]*)$/i', $column, $matches) === 1) {
            return $grammar->qualify(trim($matches[1])) . ' AS ' . $grammar->quote($matches[2]);
        }
        return $grammar->qualify($column);
    }

    /** @return array{sql: string, bindings: list<mixed>} */
    public function compile(Dialect $dialect = Dialect::PostgreSQL): array
    {
        $grammar = Grammar::for($dialect);
        $bindings = new Bindings();
        $sql = $this->compileInto($grammar, $bindings);

        return ['sql' => $sql, 'bindings' => $bindings->all()];
    }

    /** The query as it would be sent, wrapped for reading. */
    public function explain(Dialect $dialect = Dialect::PostgreSQL): string
    {
        ['sql' => $sql, 'bindings' => $values] = $this->compile($dialect);

        $wrapped = preg_replace(
            '/\s(FROM|WHERE|GROUP BY|HAVING|ORDER BY|LIMIT|INNER JOIN|LEFT JOIN|RIGHT JOIN|CROSS JOIN)\s/',
            "\n  $1 ",
            $sql,
        ) ?? $sql;

        $lines = ['  ' . $wrapped];
        if ($values !== []) {
            $lines[] = '  -- bindings: ' . implode(', ', array_map(
                static fn (mixed $value): string => match (true) {
                    $value === null => 'NULL',
                    is_bool($value) => $value ? 'true' : 'false',
                    is_int($value), is_float($value) => (string) $value,
                    default => "'" . $value . "'",
                },
                $values,
            ));
        }
        return implode("\n", $lines);
    }
}

// --------------------------------------------------------------------- demo

function heading(string $title): void
{
    echo "\n--- {$title} ---\n";
}

function main(): int
{
    heading('a plain query');
    echo QueryBuilder::from('routes')
        ->select('code', 'name', 'active')
        ->where('active', true)
        ->orderBy('code')
        ->explain(), "\n";

    heading('the same query in three dialects');
    $query = QueryBuilder::from('sailings', 's')
        ->select('s.id', 's.departs', 'r.name AS route')
        ->join('routes', 's.route_code', '=', 'r.code', alias: 'r')
        ->where('s.seats', '>=', 200)
        ->orderBy('s.departs')
        ->limit(10);

    foreach ([Dialect::PostgreSQL, Dialect::MySQL, Dialect::SQLite] as $dialect) {
        printf("  %s\n%s\n\n", $dialect->name, $query->explain($dialect));
    }

    heading('conditions of every kind');
    echo QueryBuilder::from('sailings')
        ->select('id', 'route_code', 'departs', 'seats')
        ->whereIn('route_code', ['HRB', 'KSP', 'HLW'])
        ->whereBetween('seats', 100, 400)
        ->whereNotNull('vessel')
        ->whereNotIn('status', ['cancelled', 'draft'])
        ->where('departs', 'LIKE', '0%')
        ->orderBy('departs', Direction::Desc)
        ->explain(), "\n";

    heading('a bracketed group');
    echo QueryBuilder::from('sailings')
        ->where('active', true)
        ->whereGroup(static fn (QueryBuilder $q): QueryBuilder => $q
            ->where('route_code', 'HRB')
            ->orWhere('route_code', 'KSP'))
        ->explain(), "\n";

    heading('aggregation');
    echo QueryBuilder::from('sailings', 's')
        ->select('s.route_code', 'COUNT(*) AS sailings', 'SUM(s.seats) AS capacity')
        ->leftJoin('routes', 's.route_code', '=', 'r.code', 'r')
        ->where('s.departs', '>=', '06:00')
        ->groupBy('s.route_code')
        ->having('COUNT(*)', '>', 3)
        ->orderBy('capacity', Direction::Desc)
        ->explain(), "\n";

    heading('a subquery');
    $cancelled = QueryBuilder::from('events', 'e')
        ->select('1')
        ->where('e.kind', 'cancelled')
        ->where('e.sailing_id', '=', 'placeholder-for-the-example');

    echo QueryBuilder::from('sailings', 's')
        ->select('s.id', 's.departs')
        ->where('s.route_code', 'HRB')
        ->whereNotExists($cancelled)
        ->explain(), "\n";
    echo "  Note how the subquery's placeholders continue the parent's numbering.\n";

    heading('paging');
    $base = QueryBuilder::from('sailings')->select('id', 'departs')->orderBy('departs');
    foreach ([1, 2, 5] as $page) {
        ['sql' => $sql] = $base->page($page, 20)->compile();
        printf("  page %d: %s\n", $page, substr($sql, strrpos($sql, 'ORDER BY') ?: 0));
    }

    heading('the builder is a value, not a mutable object');
    $shared = QueryBuilder::from('routes')->where('active', true);
    $north = $shared->where('region', 'north');
    $south = $shared->where('region', 'south');
    printf("  shared: %s\n", $shared->compile()['sql']);
    printf("  north:  %s\n", $north->compile()['sql']);
    printf("  south:  %s\n", $south->compile()['sql']);
    printf("  the shared query was not modified by either: %s\n",
        str_contains($shared->compile()['sql'], 'region') ? 'no' : 'yes');

    heading('dynamic where methods');
    echo QueryBuilder::from('routes')
        ->whereCode('HRB')
        ->whereActive(true)
        ->explain(), "\n";

    heading('values never reach the sql');
    $nasty = "'; DROP TABLE routes; --";
    ['sql' => $sql, 'bindings' => $values] = QueryBuilder::from('routes')
        ->where('name', $nasty)
        ->compile();
    printf("  sql:      %s\n", $sql);
    printf("  bindings: %s\n", var_export($values, true));
    printf("  the sql contains the payload: %s\n",
        str_contains($sql, 'DROP') ? 'YES, which would be a bug' : 'no');

    heading('identifiers are quoted, and quotes inside them escaped');
    printf("  %s\n", QueryBuilder::from('odd"name')->compile()['sql']);
    printf("  %s\n", QueryBuilder::from('odd`name')->compile(Dialect::MySQL)['sql']);

    heading('what the builder refuses');
    $attempts = [
        'an unknown operator' => static fn () => QueryBuilder::from('t')->where('a', '=>', 1),
        'IN with no values' => static fn () => QueryBuilder::from('t')->whereIn('a', []),
        'a negative limit' => static fn () => QueryBuilder::from('t')->limit(-1),
        'page zero' => static fn () => QueryBuilder::from('t')->page(0, 10),
        'an unknown method' => static fn () => QueryBuilder::from('t')->orderByMagic('a'),
        'writing to bindings' => static function (): void {
            $bindings = new Bindings();
            $bindings[0] = 'nope';
        },
    ];
    foreach ($attempts as $label => $attempt) {
        try {
            $attempt();
            printf("  %-22s unexpectedly accepted\n", $label);
        } catch (InvalidArgumentException | BadMethodCallException | LogicException $error) {
            printf("  %-22s %s\n", $label, $error->getMessage());
        }
    }

    heading('bindings are countable and iterable');
    $bindings = new Bindings();
    $bindings->addMany(['HRB', 200, true, null]);
    printf("  %d binding(s): %s\n", count($bindings), $bindings->describe());
    foreach ($bindings as $index => $value) {
        printf("    %d => %s\n", $index, var_export($value, true));
    }

    return 0;
}

exit(main());
