#!/usr/bin/env python3
"""A small Lisp interpreter: tokeniser, reader, evaluator, and a REPL.

The dialect is deliberately tiny but not a toy — it has lexical closures, tail
positions that do not grow the Python stack for `if` and `begin`, proper
`quote`/`quasiquote`, variadic lambdas, macros, and enough builtins to write
useful programs. Everything lives in this one file and uses only the standard
library.

Run it with an argument to evaluate a file, or with none for a REPL:

    python3 lisp_interpreter.py program.lisp
    python3 lisp_interpreter.py

The language:

    (define x 10)
    (define (square n) (* n n))
    (define add (lambda (a b) (+ a b)))
    (if (> x 5) 'big 'small)
    (let ((a 1) (b 2)) (+ a b))
    (cond ((< x 0) 'negative) ((= x 0) 'zero) (else 'positive))
    (define-macro (unless test . body) `(if ,test (quote ()) (begin ,@body)))
"""

from __future__ import annotations

import math
import operator
import sys
from typing import Any, Iterator


# --------------------------------------------------------------------- errors


class LispError(Exception):
    """Base class for anything this interpreter reports to the user."""


class ParseError(LispError):
    pass


class EvalError(LispError):
    pass


# ---------------------------------------------------------------------- types


class Symbol(str):
    """A distinct type so that symbols and strings do not compare equal."""

    __slots__ = ()

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"Symbol({str.__repr__(self)})"


class Pair:
    """A cons cell. Lists are chains of pairs ending in the empty list."""

    __slots__ = ("car", "cdr")

    def __init__(self, car: Any, cdr: Any) -> None:
        self.car = car
        self.cdr = cdr

    def __iter__(self) -> Iterator[Any]:
        node: Any = self
        while isinstance(node, Pair):
            yield node.car
            node = node.cdr
        if node is not NIL:
            raise EvalError("improper list used where a proper list was needed")

    def __eq__(self, other: object) -> bool:
        return (
            isinstance(other, Pair)
            and self.car == other.car
            and self.cdr == other.cdr
        )

    def __repr__(self) -> str:
        return write(self)


class Nil:
    """The empty list. A singleton, false in a boolean context."""

    _instance = None

    def __new__(cls) -> "Nil":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __iter__(self) -> Iterator[Any]:
        return iter(())

    def __bool__(self) -> bool:
        return False

    def __repr__(self) -> str:
        return "()"


NIL = Nil()

QUOTE = Symbol("quote")
QUASIQUOTE = Symbol("quasiquote")
UNQUOTE = Symbol("unquote")
UNQUOTE_SPLICING = Symbol("unquote-splicing")


def from_list(items: list[Any], tail: Any = NIL) -> Any:
    """Build a chain of pairs from a Python list."""
    result: Any = tail
    for item in reversed(items):
        result = Pair(item, result)
    return result


def to_list(value: Any) -> list[Any]:
    """Flatten a proper list into a Python list."""
    out = []
    node = value
    while isinstance(node, Pair):
        out.append(node.car)
        node = node.cdr
    if node is not NIL:
        raise EvalError(f"improper list: {write(value)}")
    return out


# ------------------------------------------------------------------ tokeniser


DELIMITERS = set("()'`,\"; \t\n\r")


def tokenize(source: str) -> list[str]:
    """Split source text into tokens, discarding comments and whitespace."""
    tokens: list[str] = []
    index = 0
    length = len(source)

    while index < length:
        char = source[index]

        if char in " \t\n\r":
            index += 1
        elif char == ";":
            while index < length and source[index] != "\n":
                index += 1
        elif char in "()":
            tokens.append(char)
            index += 1
        elif char == "'":
            tokens.append("'")
            index += 1
        elif char == "`":
            tokens.append("`")
            index += 1
        elif char == ",":
            if index + 1 < length and source[index + 1] == "@":
                tokens.append(",@")
                index += 2
            else:
                tokens.append(",")
                index += 1
        elif char == '"':
            start = index
            index += 1
            while index < length and source[index] != '"':
                if source[index] == "\\":
                    index += 1
                index += 1
            if index >= length:
                raise ParseError("unterminated string literal")
            index += 1
            tokens.append(source[start:index])
        else:
            start = index
            while index < length and source[index] not in DELIMITERS:
                index += 1
            tokens.append(source[start:index])

    return tokens


ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}


def atom(token: str) -> Any:
    """Turn a single token into a number, string, boolean, or symbol."""
    if token == "#t":
        return True
    if token == "#f":
        return False
    if token.startswith('"'):
        body = token[1:-1]
        out = []
        index = 0
        while index < len(body):
            if body[index] == "\\" and index + 1 < len(body):
                out.append(ESCAPES.get(body[index + 1], body[index + 1]))
                index += 2
            else:
                out.append(body[index])
                index += 1
        return "".join(out)
    try:
        return int(token)
    except ValueError:
        pass
    try:
        return float(token)
    except ValueError:
        pass
    return Symbol(token)


READER_MACROS = {"'": QUOTE, "`": QUASIQUOTE, ",": UNQUOTE, ",@": UNQUOTE_SPLICING}


def read_from(tokens: list[str], position: int = 0) -> tuple[Any, int]:
    """Read one expression, returning it and the position after it."""
    if position >= len(tokens):
        raise ParseError("unexpected end of input")

    token = tokens[position]
    position += 1

    if token in READER_MACROS:
        expression, position = read_from(tokens, position)
        return from_list([READER_MACROS[token], expression]), position

    if token == "(":
        items: list[Any] = []
        tail: Any = NIL
        while True:
            if position >= len(tokens):
                raise ParseError("unclosed '('")
            if tokens[position] == ")":
                position += 1
                break
            if tokens[position] == "." and items:
                position += 1
                tail, position = read_from(tokens, position)
                if position >= len(tokens) or tokens[position] != ")":
                    raise ParseError("expected ')' after dotted tail")
                position += 1
                break
            item, position = read_from(tokens, position)
            items.append(item)
        return from_list(items, tail), position

    if token == ")":
        raise ParseError("unexpected ')'")

    return atom(token), position


def read_all(source: str) -> list[Any]:
    """Read every expression in a source string."""
    tokens = tokenize(source)
    expressions = []
    position = 0
    while position < len(tokens):
        expression, position = read_from(tokens, position)
        expressions.append(expression)
    return expressions


# ---------------------------------------------------------------------- write


def write(value: Any) -> str:
    """Render a value the way the reader would accept it back."""
    if value is True:
        return "#t"
    if value is False:
        return "#f"
    if value is NIL:
        return "()"
    if isinstance(value, Symbol):
        return str(value)
    if isinstance(value, str):
        escaped = (
            value.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\t", "\\t")
        )
        return f'"{escaped}"'
    if isinstance(value, Pair):
        parts = []
        node: Any = value
        while isinstance(node, Pair):
            parts.append(write(node.car))
            node = node.cdr
        if node is NIL:
            return "(" + " ".join(parts) + ")"
        return "(" + " ".join(parts) + " . " + write(node) + ")"
    if isinstance(value, Procedure):
        return f"#<procedure {value.name}>"
    if callable(value):
        return f"#<builtin {getattr(value, '__name__', '?')}>"
    if isinstance(value, float) and value.is_integer():
        return str(int(value)) + ".0"
    return str(value)


# ---------------------------------------------------------------- environment


class Environment:
    """A scope: a table of bindings and a link to the enclosing scope."""

    __slots__ = ("bindings", "parent")

    def __init__(self, bindings: dict[str, Any] | None = None,
                 parent: "Environment | None" = None) -> None:
        self.bindings = bindings if bindings is not None else {}
        self.parent = parent

    def lookup(self, name: str) -> Any:
        scope: Environment | None = self
        while scope is not None:
            if name in scope.bindings:
                return scope.bindings[name]
            scope = scope.parent
        raise EvalError(f"unbound symbol: {name}")

    def define(self, name: str, value: Any) -> None:
        self.bindings[name] = value

    def assign(self, name: str, value: Any) -> None:
        scope: Environment | None = self
        while scope is not None:
            if name in scope.bindings:
                scope.bindings[name] = value
                return
            scope = scope.parent
        raise EvalError(f"cannot set! an unbound symbol: {name}")


class Procedure:
    """A closure: parameters, a body, and the environment it was made in."""

    __slots__ = ("params", "rest", "body", "env", "name")

    def __init__(self, params: list[str], rest: str | None, body: list[Any],
                 env: Environment, name: str = "anonymous") -> None:
        self.params = params
        self.rest = rest
        self.body = body
        self.env = env
        self.name = name

    def bind(self, args: list[Any]) -> Environment:
        if self.rest is None and len(args) != len(self.params):
            raise EvalError(
                f"{self.name} expects {len(self.params)} argument(s), "
                f"got {len(args)}"
            )
        if self.rest is not None and len(args) < len(self.params):
            raise EvalError(
                f"{self.name} expects at least {len(self.params)} argument(s), "
                f"got {len(args)}"
            )
        bindings = dict(zip(self.params, args))
        if self.rest is not None:
            bindings[self.rest] = from_list(args[len(self.params):])
        return Environment(bindings, self.env)


class Macro(Procedure):
    """A procedure applied to unevaluated forms, whose result is evaluated."""

    __slots__ = ()


def parse_parameters(spec: Any) -> tuple[list[str], str | None]:
    """Read a lambda list, which may end in a dotted rest parameter."""
    if isinstance(spec, Symbol):
        return [], str(spec)
    params: list[str] = []
    node = spec
    while isinstance(node, Pair):
        if not isinstance(node.car, Symbol):
            raise EvalError(f"parameter is not a symbol: {write(node.car)}")
        params.append(str(node.car))
        node = node.cdr
    if node is NIL:
        return params, None
    if isinstance(node, Symbol):
        return params, str(node)
    raise EvalError(f"malformed parameter list: {write(spec)}")


# ------------------------------------------------------------------ evaluator


def evaluate(expression: Any, env: Environment) -> Any:
    """Evaluate one expression, looping rather than recursing in tail position."""
    while True:
        if isinstance(expression, Symbol):
            return env.lookup(str(expression))

        if not isinstance(expression, Pair):
            return expression  # numbers, strings, booleans, ()

        head = expression.car
        args = expression.cdr

        if isinstance(head, Symbol):
            name = str(head)

            if name == "quote":
                return args.car

            if name == "quasiquote":
                return quasiquote(args.car, env, 1)

            if name == "if":
                parts = to_list(args)
                if len(parts) not in (2, 3):
                    raise EvalError("if takes 2 or 3 forms")
                if is_true(evaluate(parts[0], env)):
                    expression = parts[1]
                elif len(parts) == 3:
                    expression = parts[2]
                else:
                    return NIL
                continue  # tail position

            if name == "define":
                target = args.car
                if isinstance(target, Pair):
                    proc_name = str(target.car)
                    params, rest = parse_parameters(target.cdr)
                    env.define(
                        proc_name,
                        Procedure(params, rest, to_list(args.cdr), env, proc_name),
                    )
                    return Symbol(proc_name)
                value = evaluate(args.cdr.car, env) if args.cdr is not NIL else NIL
                if isinstance(value, Procedure) and value.name == "anonymous":
                    value.name = str(target)
                env.define(str(target), value)
                return target

            if name == "define-macro":
                target = args.car
                macro_name = str(target.car)
                params, rest = parse_parameters(target.cdr)
                env.define(
                    macro_name,
                    Macro(params, rest, to_list(args.cdr), env, macro_name),
                )
                return Symbol(macro_name)

            if name == "set!":
                env.assign(str(args.car), evaluate(args.cdr.car, env))
                return NIL

            if name == "lambda":
                params, rest = parse_parameters(args.car)
                return Procedure(params, rest, to_list(args.cdr), env)

            if name == "begin":
                body = to_list(args)
                if not body:
                    return NIL
                for form in body[:-1]:
                    evaluate(form, env)
                expression = body[-1]
                continue  # tail position

            if name == "let":
                bindings = to_list(args.car)
                names = [str(b.car) for b in bindings]
                values = [evaluate(b.cdr.car, env) for b in bindings]
                env = Environment(dict(zip(names, values)), env)
                expression = Pair(Symbol("begin"), args.cdr)
                continue

            if name == "let*":
                env = Environment({}, env)
                for binding in to_list(args.car):
                    env.define(str(binding.car), evaluate(binding.cdr.car, env))
                expression = Pair(Symbol("begin"), args.cdr)
                continue

            if name == "letrec":
                bindings = to_list(args.car)
                env = Environment({str(b.car): NIL for b in bindings}, env)
                for binding in bindings:
                    env.assign(str(binding.car), evaluate(binding.cdr.car, env))
                expression = Pair(Symbol("begin"), args.cdr)
                continue

            if name == "cond":
                chosen = None
                for clause in to_list(args):
                    test = clause.car
                    if isinstance(test, Symbol) and str(test) == "else":
                        chosen = Pair(Symbol("begin"), clause.cdr)
                        break
                    result = evaluate(test, env)
                    if is_true(result):
                        if clause.cdr is NIL:
                            return result
                        chosen = Pair(Symbol("begin"), clause.cdr)
                        break
                if chosen is None:
                    return NIL
                expression = chosen
                continue

            if name == "and":
                forms = to_list(args)
                if not forms:
                    return True
                for form in forms[:-1]:
                    if not is_true(evaluate(form, env)):
                        return False
                expression = forms[-1]
                continue

            if name == "or":
                forms = to_list(args)
                if not forms:
                    return False
                for form in forms[:-1]:
                    value = evaluate(form, env)
                    if is_true(value):
                        return value
                expression = forms[-1]
                continue

            if name == "while":
                test = args.car
                body = to_list(args.cdr)
                while is_true(evaluate(test, env)):
                    for form in body:
                        evaluate(form, env)
                return NIL

        operator_value = evaluate(head, env)

        if isinstance(operator_value, Macro):
            expanded = evaluate(
                Pair(Symbol("begin"), from_list(operator_value.body)),
                operator_value.bind(to_list(args)),
            )
            expression = expanded
            continue

        arguments = [evaluate(arg, env) for arg in to_list(args)]

        if isinstance(operator_value, Procedure):
            env = operator_value.bind(arguments)
            expression = Pair(Symbol("begin"), from_list(operator_value.body))
            continue  # tail call, no Python recursion

        if callable(operator_value):
            return operator_value(*arguments)

        raise EvalError(f"not applicable: {write(operator_value)}")


def quasiquote(template: Any, env: Environment, depth: int) -> Any:
    """Expand a quasiquoted template, honouring nesting depth."""
    if not isinstance(template, Pair):
        return template

    head = template.car

    if isinstance(head, Symbol):
        if str(head) == "unquote":
            if depth == 1:
                return evaluate(template.cdr.car, env)
            return from_list(
                [UNQUOTE, quasiquote(template.cdr.car, env, depth - 1)]
            )
        if str(head) == "quasiquote":
            return from_list(
                [QUASIQUOTE, quasiquote(template.cdr.car, env, depth + 1)]
            )

    if isinstance(head, Pair) and isinstance(head.car, Symbol):
        if str(head.car) == "unquote-splicing" and depth == 1:
            spliced = evaluate(head.cdr.car, env)
            rest = quasiquote(template.cdr, env, depth)
            return from_list(to_list(spliced), rest)

    return Pair(quasiquote(head, env, depth), quasiquote(template.cdr, env, depth))


def display_string(value: Any) -> str:
    """Render for a human: strings lose their quotes, everything else is
    written the way `write` writes it."""
    if isinstance(value, str) and not isinstance(value, Symbol):
        return value
    if isinstance(value, Pair):
        parts = [display_string(item) for item in to_list(value)]
        return "(" + " ".join(parts) + ")"
    return write(value)


def is_true(value: Any) -> bool:
    """Only #f and the empty list are false; 0 and "" are true."""
    return value is not False and value is not NIL


# ------------------------------------------------------------------- builtins


def numeric_fold(op, identity=None):
    def fold(*args):
        if not args:
            if identity is None:
                raise EvalError("operator needs at least one argument")
            return identity
        if len(args) == 1 and identity is not None:
            return op(identity, args[0])
        result = args[0]
        for value in args[1:]:
            result = op(result, value)
        return result

    return fold


def comparison(op):
    def compare(*args):
        if len(args) < 2:
            return True
        return all(op(args[i], args[i + 1]) for i in range(len(args) - 1))

    return compare


def builtin_list(*args):
    return from_list(list(args))


def builtin_append(*lists):
    items: list[Any] = []
    for value in lists[:-1]:
        items.extend(to_list(value))
    tail = lists[-1] if lists else NIL
    return from_list(items, tail)


def builtin_map(procedure, *lists):
    columns = [to_list(value) for value in lists]
    return from_list([apply_procedure(procedure, list(row)) for row in zip(*columns)])


def builtin_filter(predicate, value):
    return from_list(
        [item for item in to_list(value) if is_true(apply_procedure(predicate, [item]))]
    )


def builtin_reduce(procedure, initial, value):
    result = initial
    for item in to_list(value):
        result = apply_procedure(procedure, [result, item])
    return result


def apply_procedure(procedure: Any, arguments: list[Any]) -> Any:
    """Call a procedure or builtin from Python code."""
    if isinstance(procedure, Procedure):
        return evaluate(
            Pair(Symbol("begin"), from_list(procedure.body)),
            procedure.bind(arguments),
        )
    if callable(procedure):
        return procedure(*arguments)
    raise EvalError(f"not applicable: {write(procedure)}")


def standard_environment() -> Environment:
    """Build the global environment."""
    env = Environment()
    env.bindings.update(
        {
            "+": numeric_fold(operator.add, 0),
            "-": numeric_fold(operator.sub),
            "*": numeric_fold(operator.mul, 1),
            "/": numeric_fold(operator.truediv),
            "modulo": operator.mod,
            "quotient": operator.floordiv,
            "abs": abs,
            "min": min,
            "max": max,
            "expt": operator.pow,
            "sqrt": math.sqrt,
            "floor": math.floor,
            "ceiling": math.ceil,
            "=": comparison(operator.eq),
            "<": comparison(operator.lt),
            ">": comparison(operator.gt),
            "<=": comparison(operator.le),
            ">=": comparison(operator.ge),
            "not": lambda value: not is_true(value),
            "cons": Pair,
            "car": lambda pair: pair.car,
            "cdr": lambda pair: pair.cdr,
            "list": builtin_list,
            "length": lambda value: len(to_list(value)),
            "append": builtin_append,
            "reverse": lambda value: from_list(list(reversed(to_list(value)))),
            "map": builtin_map,
            "filter": builtin_filter,
            "reduce": builtin_reduce,
            "apply": lambda proc, args: apply_procedure(proc, to_list(args)),
            "null?": lambda value: value is NIL,
            "pair?": lambda value: isinstance(value, Pair),
            "symbol?": lambda value: isinstance(value, Symbol),
            "string?": lambda value: isinstance(value, str)
            and not isinstance(value, Symbol),
            "number?": lambda value: isinstance(value, (int, float))
            and not isinstance(value, bool),
            "procedure?": lambda value: isinstance(value, Procedure) or callable(value),
            "eq?": lambda a, b: a is b or a == b,
            "string-append": lambda *parts: "".join(parts),
            "string-length": len,
            "string->symbol": Symbol,
            "symbol->string": str,
            "number->string": lambda value: write(value),
            "display": lambda value: (print(display_string(value), end=""), NIL)[1],
            "write": lambda value: (print(write(value), end=""), NIL)[1],
            "newline": lambda: (print(), NIL)[1],
            "error": lambda message, *rest: (_ for _ in ()).throw(
                EvalError(f"{message} {' '.join(write(r) for r in rest)}".strip())
            ),
        }
    )
    return env


PRELUDE = """
(define (caar p) (car (car p)))
(define (cadr p) (car (cdr p)))
(define (cddr p) (cdr (cdr p)))
(define (caddr p) (car (cddr p)))

(define (list-ref items n)
  (if (= n 0) (car items) (list-ref (cdr items) (- n 1))))

(define (member? x items)
  (cond ((null? items) #f)
        ((eq? x (car items)) #t)
        (else (member? x (cdr items)))))

(define (range from to)
  (if (>= from to) '() (cons from (range (+ from 1) to))))

(define (sum items) (reduce + 0 items))

(define-macro (unless test . body)
  `(if ,test '() (begin ,@body)))

(define-macro (when test . body)
  `(if ,test (begin ,@body) '()))
"""


# ----------------------------------------------------------------------- main


def run_source(source: str, env: Environment) -> Any:
    result: Any = NIL
    for expression in read_all(source):
        result = evaluate(expression, env)
    return result


def repl(env: Environment) -> None:
    print("lisp> a tiny Lisp. Ctrl-D to leave.")
    buffer = ""
    while True:
        try:
            prompt = "lisp> " if not buffer else "  ... "
            line = input(prompt)
        except (EOFError, KeyboardInterrupt):
            print()
            return

        buffer += line + "\n"
        if buffer.count("(") > buffer.count(")"):
            continue

        try:
            result = run_source(buffer, env)
            if result is not NIL:
                print(write(result))
        except LispError as error:
            print(f"error: {error}")
        except RecursionError:
            print("error: recursion too deep")
        buffer = ""


def main(argv: list[str]) -> int:
    env = standard_environment()
    run_source(PRELUDE, env)

    if len(argv) > 1:
        try:
            with open(argv[1], encoding="utf-8") as handle:
                run_source(handle.read(), env)
        except OSError as error:
            print(f"cannot read {argv[1]}: {error}", file=sys.stderr)
            return 2
        except LispError as error:
            print(f"error: {error}", file=sys.stderr)
            return 1
        return 0

    repl(env)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
