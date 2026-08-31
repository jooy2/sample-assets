// expression_interpreter.cpp — a calculator language with a real front end.
//
// Tokeniser, Pratt (precedence-climbing) parser, an AST of polymorphic nodes,
// a tree-walking evaluator, variables, user-defined functions, built-ins, and
// error reporting that points at the offending column.
//
//   c++ -std=c++20 -Wall -Wextra -O2 -o calc expression_interpreter.cpp
//   ./calc                 run the built-in session
//   ./calc -i              read expressions from standard input
//
// The language:
//
//   1 + 2 * 3 ^ 2          arithmetic with the usual precedence
//   x = 10; y = x * 2      assignment, statements separated by semicolons
//   f(a, b) = a*a + b*b    a user-defined function
//   max(3, min(9, 5))      built-ins
//   -3 ^ 2                 unary minus binds looser than ^, so this is -9
//   x > 0 ? sqrt(x) : 0    a conditional expression
//
// One translation unit, standard library only.

#include <algorithm>
#include <cctype>
#include <cmath>
#include <functional>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace calc {

// ----------------------------------------------------------------- diagnostics

/// An error that knows where in the source line it happened.
class CalcError : public std::runtime_error {
public:
    CalcError(std::string message, std::size_t column)
        : std::runtime_error(std::move(message)), column_(column) {}

    std::size_t column() const noexcept { return column_; }

    /// The source line with a caret under the offending column.
    std::string annotate(const std::string& source) const {
        std::ostringstream out;
        out << "  " << source << '\n'
            << "  " << std::string(column_, ' ') << "^ " << what();
        return out.str();
    }

private:
    std::size_t column_;
};

// -------------------------------------------------------------------- tokens

enum class TokenKind {
    Number, Identifier,
    Plus, Minus, Star, Slash, Percent, Caret,
    Less, LessEqual, Greater, GreaterEqual, EqualEqual, BangEqual,
    Bang, Question, Colon,
    Assign, Comma, Semicolon, LeftParen, RightParen,
    End
};

struct Token {
    TokenKind   kind{TokenKind::End};
    std::string text;
    double      number{0};
    std::size_t column{0};
};

std::string_view describe(TokenKind kind) {
    switch (kind) {
    case TokenKind::Number:       return "a number";
    case TokenKind::Identifier:   return "a name";
    case TokenKind::Plus:         return "'+'";
    case TokenKind::Minus:        return "'-'";
    case TokenKind::Star:         return "'*'";
    case TokenKind::Slash:        return "'/'";
    case TokenKind::Percent:      return "'%'";
    case TokenKind::Caret:        return "'^'";
    case TokenKind::Less:         return "'<'";
    case TokenKind::LessEqual:    return "'<='";
    case TokenKind::Greater:      return "'>'";
    case TokenKind::GreaterEqual: return "'>='";
    case TokenKind::EqualEqual:   return "'=='";
    case TokenKind::BangEqual:    return "'!='";
    case TokenKind::Bang:         return "'!'";
    case TokenKind::Question:     return "'?'";
    case TokenKind::Colon:        return "':'";
    case TokenKind::Assign:       return "'='";
    case TokenKind::Comma:        return "','";
    case TokenKind::Semicolon:    return "';'";
    case TokenKind::LeftParen:    return "'('";
    case TokenKind::RightParen:   return "')'";
    case TokenKind::End:          return "the end of the input";
    }
    return "something";
}

/// Turn source text into tokens. Reports the column of anything it cannot read.
std::vector<Token> tokenise(const std::string& source) {
    std::vector<Token> tokens;
    std::size_t i = 0;

    auto push = [&](TokenKind kind, std::string text, std::size_t column) {
        tokens.push_back(Token{kind, std::move(text), 0, column});
    };

    while (i < source.size()) {
        const char c = source[i];

        if (std::isspace(static_cast<unsigned char>(c))) { ++i; continue; }

        if (c == '#') {                       // a comment runs to end of line
            while (i < source.size() && source[i] != '\n') ++i;
            continue;
        }

        const std::size_t start = i;

        if (std::isdigit(static_cast<unsigned char>(c)) || c == '.') {
            while (i < source.size()
                   && (std::isdigit(static_cast<unsigned char>(source[i]))
                       || source[i] == '.')) {
                ++i;
            }
            // An exponent, but only when it really is one: 1e3, not 1en.
            if (i < source.size() && (source[i] == 'e' || source[i] == 'E')) {
                std::size_t look = i + 1;
                if (look < source.size() && (source[look] == '+' || source[look] == '-')) {
                    ++look;
                }
                if (look < source.size()
                    && std::isdigit(static_cast<unsigned char>(source[look]))) {
                    i = look;
                    while (i < source.size()
                           && std::isdigit(static_cast<unsigned char>(source[i]))) {
                        ++i;
                    }
                }
            }

            const std::string text = source.substr(start, i - start);
            std::size_t consumed = 0;
            double value = 0;
            try {
                value = std::stod(text, &consumed);
            } catch (const std::exception&) {
                throw CalcError("not a number: " + text, start);
            }
            if (consumed != text.size()) {
                throw CalcError("not a number: " + text, start);
            }

            Token token{TokenKind::Number, text, value, start};
            tokens.push_back(token);
            continue;
        }

        if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') {
            while (i < source.size()
                   && (std::isalnum(static_cast<unsigned char>(source[i]))
                       || source[i] == '_')) {
                ++i;
            }
            push(TokenKind::Identifier, source.substr(start, i - start), start);
            continue;
        }

        // Two-character operators first, so '<=' never reads as '<' then '='.
        const std::string two = source.substr(i, 2);
        static const std::map<std::string, TokenKind> pairs{
            {"<=", TokenKind::LessEqual},   {">=", TokenKind::GreaterEqual},
            {"==", TokenKind::EqualEqual},  {"!=", TokenKind::BangEqual},
        };
        if (auto found = pairs.find(two); found != pairs.end()) {
            push(found->second, two, start);
            i += 2;
            continue;
        }

        static const std::map<char, TokenKind> singles{
            {'+', TokenKind::Plus},      {'-', TokenKind::Minus},
            {'*', TokenKind::Star},      {'/', TokenKind::Slash},
            {'%', TokenKind::Percent},   {'^', TokenKind::Caret},
            {'<', TokenKind::Less},      {'>', TokenKind::Greater},
            {'!', TokenKind::Bang},      {'?', TokenKind::Question},
            {':', TokenKind::Colon},     {'=', TokenKind::Assign},
            {',', TokenKind::Comma},     {';', TokenKind::Semicolon},
            {'(', TokenKind::LeftParen}, {')', TokenKind::RightParen},
        };
        if (auto found = singles.find(c); found != singles.end()) {
            push(found->second, std::string(1, c), start);
            ++i;
            continue;
        }

        throw CalcError(std::string("unexpected character '") + c + "'", start);
    }

    tokens.push_back(Token{TokenKind::End, "", 0, source.size()});
    return tokens;
}

// ----------------------------------------------------------------- the tree

class Environment;

struct Node {
    virtual ~Node() = default;
    virtual double evaluate(Environment& env) const = 0;
    virtual void   print(std::ostream& out) const = 0;
};

using NodePtr = std::unique_ptr<Node>;

struct NumberNode final : Node {
    double value;
    explicit NumberNode(double value) : value(value) {}

    double evaluate(Environment&) const override { return value; }
    void print(std::ostream& out) const override { out << value; }
};

struct VariableNode final : Node {
    std::string name;
    std::size_t column;
    VariableNode(std::string name, std::size_t column)
        : name(std::move(name)), column(column) {}

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override { out << name; }
};

struct UnaryNode final : Node {
    std::string op;
    NodePtr     operand;
    std::size_t column;

    UnaryNode(std::string op, NodePtr operand, std::size_t column)
        : op(std::move(op)), operand(std::move(operand)), column(column) {}

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override {
        out << '(' << op;
        operand->print(out);
        out << ')';
    }
};

struct BinaryNode final : Node {
    std::string op;
    NodePtr     left;
    NodePtr     right;
    std::size_t column;

    BinaryNode(std::string op, NodePtr left, NodePtr right, std::size_t column)
        : op(std::move(op)), left(std::move(left)),
          right(std::move(right)), column(column) {}

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override {
        out << '(';
        left->print(out);
        out << ' ' << op << ' ';
        right->print(out);
        out << ')';
    }
};

struct ConditionalNode final : Node {
    NodePtr test, whenTrue, whenFalse;

    ConditionalNode(NodePtr test, NodePtr whenTrue, NodePtr whenFalse)
        : test(std::move(test)), whenTrue(std::move(whenTrue)),
          whenFalse(std::move(whenFalse)) {}

    double evaluate(Environment& env) const override {
        return test->evaluate(env) != 0.0 ? whenTrue->evaluate(env)
                                          : whenFalse->evaluate(env);
    }
    void print(std::ostream& out) const override {
        out << '(';
        test->print(out);
        out << " ? ";
        whenTrue->print(out);
        out << " : ";
        whenFalse->print(out);
        out << ')';
    }
};

struct AssignNode final : Node {
    std::string name;
    NodePtr     value;

    AssignNode(std::string name, NodePtr value)
        : name(std::move(name)), value(std::move(value)) {}

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override {
        out << '(' << name << " = ";
        value->print(out);
        out << ')';
    }
};

struct CallNode final : Node {
    std::string          name;
    std::vector<NodePtr> arguments;
    std::size_t          column;

    CallNode(std::string name, std::vector<NodePtr> arguments, std::size_t column)
        : name(std::move(name)), arguments(std::move(arguments)), column(column) {}

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override {
        out << name << '(';
        for (std::size_t i = 0; i < arguments.size(); ++i) {
            if (i) out << ", ";
            arguments[i]->print(out);
        }
        out << ')';
    }
};

/// A function the user defined: parameter names and a body to evaluate.
struct FunctionDefinition {
    std::vector<std::string> parameters;
    std::shared_ptr<Node>    body;
};

struct DefineNode final : Node {
    std::string              name;
    std::vector<std::string> parameters;
    std::shared_ptr<Node>    body;

    double evaluate(Environment& env) const override;
    void print(std::ostream& out) const override {
        out << name << '(';
        for (std::size_t i = 0; i < parameters.size(); ++i) {
            if (i) out << ", ";
            out << parameters[i];
        }
        out << ") = ";
        body->print(out);
    }
};

// ------------------------------------------------------------- environment

using Builtin = std::function<double(const std::vector<double>&)>;

struct BuiltinInfo {
    Builtin     fn;
    int         minArity;
    int         maxArity;   // -1 for variadic
    std::string help;
};

class Environment {
public:
    Environment() { installBuiltins(); }

    std::optional<double> lookup(const std::string& name) const {
        if (auto found = variables_.find(name); found != variables_.end()) {
            return found->second;
        }
        return std::nullopt;
    }

    void assign(const std::string& name, double value) { variables_[name] = value; }

    void unset(const std::string& name) { variables_.erase(name); }

    void define(const std::string& name, FunctionDefinition definition) {
        functions_[name] = std::move(definition);
    }

    const FunctionDefinition* function(const std::string& name) const {
        auto found = functions_.find(name);
        return found == functions_.end() ? nullptr : &found->second;
    }

    const BuiltinInfo* builtin(const std::string& name) const {
        auto found = builtins_.find(name);
        return found == builtins_.end() ? nullptr : &found->second;
    }

    /// Guards against a function that calls itself without a base case.
    struct DepthGuard {
        explicit DepthGuard(Environment& env, std::size_t column) : env_(env) {
            if (++env_.depth_ > 200) {
                --env_.depth_;
                throw CalcError("recursion too deep", column);
            }
        }
        ~DepthGuard() { --env_.depth_; }

        DepthGuard(const DepthGuard&) = delete;
        DepthGuard& operator=(const DepthGuard&) = delete;

    private:
        Environment& env_;
    };

    std::vector<std::string> builtinNames() const {
        std::vector<std::string> names;
        names.reserve(builtins_.size());
        for (const auto& [name, info] : builtins_) names.push_back(name);
        std::sort(names.begin(), names.end());
        return names;
    }

    std::map<std::string, double> snapshot() const {
        return {variables_.begin(), variables_.end()};
    }

private:
    void installBuiltins() {
        variables_["pi"] = 3.14159265358979323846;
        variables_["e"] = 2.71828182845904523536;

        auto one = [](auto fn) {
            return [fn](const std::vector<double>& a) { return fn(a[0]); };
        };

        builtins_["sqrt"]  = {one([](double x) { return std::sqrt(x); }),  1, 1, "square root"};
        builtins_["abs"]   = {one([](double x) { return std::fabs(x); }),  1, 1, "absolute value"};
        builtins_["floor"] = {one([](double x) { return std::floor(x); }), 1, 1, "round down"};
        builtins_["ceil"]  = {one([](double x) { return std::ceil(x); }),  1, 1, "round up"};
        builtins_["round"] = {one([](double x) { return std::round(x); }), 1, 1, "round to nearest"};
        builtins_["sin"]   = {one([](double x) { return std::sin(x); }),   1, 1, "sine, radians"};
        builtins_["cos"]   = {one([](double x) { return std::cos(x); }),   1, 1, "cosine, radians"};
        builtins_["ln"]    = {one([](double x) { return std::log(x); }),   1, 1, "natural log"};
        builtins_["log"]   = {one([](double x) { return std::log10(x); }), 1, 1, "log base ten"};

        builtins_["min"] = {
            [](const std::vector<double>& a) {
                return *std::min_element(a.begin(), a.end());
            }, 1, -1, "smallest argument"};
        builtins_["max"] = {
            [](const std::vector<double>& a) {
                return *std::max_element(a.begin(), a.end());
            }, 1, -1, "largest argument"};
        builtins_["sum"] = {
            [](const std::vector<double>& a) {
                double total = 0;
                for (double v : a) total += v;
                return total;
            }, 0, -1, "sum of the arguments"};
        builtins_["mean"] = {
            [](const std::vector<double>& a) {
                double total = 0;
                for (double v : a) total += v;
                return total / static_cast<double>(a.size());
            }, 1, -1, "arithmetic mean"};
        builtins_["hypot"] = {
            [](const std::vector<double>& a) { return std::hypot(a[0], a[1]); },
            2, 2, "length of the hypotenuse"};
        builtins_["clamp"] = {
            [](const std::vector<double>& a) {
                return std::min(a[2], std::max(a[1], a[0]));
            }, 3, 3, "clamp(x, low, high)"};

        (void)0;
    }

    std::unordered_map<std::string, double>             variables_;
    std::unordered_map<std::string, FunctionDefinition> functions_;
    std::map<std::string, BuiltinInfo>                  builtins_;
    std::size_t                                         depth_{0};

    friend struct DepthGuard;
};

// ------------------------------------------------------------- evaluation

double VariableNode::evaluate(Environment& env) const {
    if (auto value = env.lookup(name)) return *value;
    throw CalcError("'" + name + "' has no value", column);
}

double UnaryNode::evaluate(Environment& env) const {
    const double value = operand->evaluate(env);
    if (op == "-") return -value;
    if (op == "+") return value;
    if (op == "!") return value == 0.0 ? 1.0 : 0.0;
    throw CalcError("unknown unary operator " + op, column);
}

double BinaryNode::evaluate(Environment& env) const {
    const double a = left->evaluate(env);
    const double b = right->evaluate(env);

    if (op == "+")  return a + b;
    if (op == "-")  return a - b;
    if (op == "*")  return a * b;
    if (op == "^")  return std::pow(a, b);
    if (op == "<")  return a <  b ? 1.0 : 0.0;
    if (op == "<=") return a <= b ? 1.0 : 0.0;
    if (op == ">")  return a >  b ? 1.0 : 0.0;
    if (op == ">=") return a >= b ? 1.0 : 0.0;
    if (op == "==") return a == b ? 1.0 : 0.0;
    if (op == "!=") return a != b ? 1.0 : 0.0;

    if (op == "/") {
        if (b == 0.0) throw CalcError("division by zero", column);
        return a / b;
    }
    if (op == "%") {
        if (b == 0.0) throw CalcError("division by zero", column);
        return std::fmod(a, b);
    }
    throw CalcError("unknown operator " + op, column);
}

double AssignNode::evaluate(Environment& env) const {
    const double result = value->evaluate(env);
    env.assign(name, result);
    return result;
}

double DefineNode::evaluate(Environment& env) const {
    env.define(name, FunctionDefinition{parameters, body});
    return 0.0;
}

double CallNode::evaluate(Environment& env) const {
    std::vector<double> values;
    values.reserve(arguments.size());
    for (const auto& argument : arguments) values.push_back(argument->evaluate(env));

    if (const BuiltinInfo* info = env.builtin(name)) {
        const int arity = static_cast<int>(values.size());
        if (arity < info->minArity
            || (info->maxArity >= 0 && arity > info->maxArity)) {
            std::ostringstream out;
            out << name << " takes ";
            if (info->maxArity < 0) out << "at least " << info->minArity;
            else if (info->minArity == info->maxArity) out << info->minArity;
            else out << info->minArity << " to " << info->maxArity;
            out << " argument(s), given " << arity;
            throw CalcError(out.str(), column);
        }
        return info->fn(values);
    }

    if (const FunctionDefinition* definition = env.function(name)) {
        if (definition->parameters.size() != values.size()) {
            throw CalcError(name + " takes "
                            + std::to_string(definition->parameters.size())
                            + " argument(s), given "
                            + std::to_string(values.size()), column);
        }

        Environment::DepthGuard guard(env, column);

        // Save the callee's parameter names, bind, evaluate, restore. Crude
        // dynamic scoping, but it keeps recursion working without a frame
        // stack, and the language has no closures for it to get wrong.
        //
        // A parameter that shadowed nothing has to be erased on the way out,
        // not merely left alone: otherwise every call quietly adds its
        // parameter names to the global scope.
        std::vector<std::pair<std::string, std::optional<double>>> saved;
        saved.reserve(values.size());
        for (std::size_t i = 0; i < values.size(); ++i) {
            saved.emplace_back(definition->parameters[i],
                               env.lookup(definition->parameters[i]));
            env.assign(definition->parameters[i], values[i]);
        }

        const auto restore = [&] {
            for (auto& [parameter, previous] : saved) {
                if (previous) env.assign(parameter, *previous);
                else          env.unset(parameter);
            }
        };

        double result = 0;
        try {
            result = definition->body->evaluate(env);
        } catch (...) {
            restore();
            throw;
        }
        restore();
        return result;
    }

    throw CalcError("no function called '" + name + "'", column);
}

// ------------------------------------------------------------------ parser

/// A Pratt parser: each operator carries a binding power, and precedence
/// falls out of comparing them rather than out of a grammar rule per level.
class Parser {
public:
    explicit Parser(std::vector<Token> tokens) : tokens_(std::move(tokens)) {}

    std::vector<NodePtr> parseProgram() {
        std::vector<NodePtr> statements;
        while (!at(TokenKind::End)) {
            statements.push_back(parseStatement());
            while (match(TokenKind::Semicolon)) { /* allow several */ }
        }
        return statements;
    }

private:
    struct Power { int left; int right; };

    static std::optional<Power> infixPower(TokenKind kind) {
        switch (kind) {
        case TokenKind::EqualEqual:
        case TokenKind::BangEqual:      return Power{2, 3};
        case TokenKind::Less:
        case TokenKind::LessEqual:
        case TokenKind::Greater:
        case TokenKind::GreaterEqual:   return Power{4, 5};
        case TokenKind::Plus:
        case TokenKind::Minus:          return Power{6, 7};
        case TokenKind::Star:
        case TokenKind::Slash:
        case TokenKind::Percent:        return Power{8, 9};
        // Right-associative: the right power is the lower of the pair, so
        // 2^3^2 parses as 2^(3^2).
        case TokenKind::Caret:          return Power{13, 12};
        default:                        return std::nullopt;
        }
    }

    static constexpr int unaryPower = 11;
    static constexpr int conditionalPower = 1;

    const Token& current() const { return tokens_[position_]; }

    bool at(TokenKind kind) const { return current().kind == kind; }

    bool match(TokenKind kind) {
        if (!at(kind)) return false;
        ++position_;
        return true;
    }

    const Token& expect(TokenKind kind) {
        if (!at(kind)) {
            std::ostringstream out;
            out << "expected " << describe(kind) << ", found "
                << describe(current().kind);
            throw CalcError(out.str(), current().column);
        }
        return tokens_[position_++];
    }

    NodePtr parseStatement() {
        // A definition or an assignment is recognised by looking ahead rather
        // than by backtracking: `name =` or `name ( ... ) =`.
        if (at(TokenKind::Identifier)) {
            if (tokens_[position_ + 1].kind == TokenKind::Assign) {
                const std::string name = tokens_[position_].text;
                position_ += 2;
                return std::make_unique<AssignNode>(name, parseExpression(0));
            }
            if (tokens_[position_ + 1].kind == TokenKind::LeftParen) {
                if (auto definition = tryParseDefinition()) return definition;
            }
        }
        return parseExpression(0);
    }

    NodePtr tryParseDefinition() {
        const std::size_t start = position_;
        const std::string name = tokens_[position_].text;

        position_ += 2;   // the name and the '('
        std::vector<std::string> parameters;

        if (!at(TokenKind::RightParen)) {
            do {
                if (!at(TokenKind::Identifier)) { position_ = start; return nullptr; }
                parameters.push_back(tokens_[position_++].text);
            } while (match(TokenKind::Comma));
        }
        if (!match(TokenKind::RightParen) || !match(TokenKind::Assign)) {
            position_ = start;
            return nullptr;
        }

        auto node = std::make_unique<DefineNode>();
        node->name = name;
        node->parameters = std::move(parameters);
        node->body = std::shared_ptr<Node>(parseExpression(0).release());
        return node;
    }

    NodePtr parseExpression(int minimumPower) {
        NodePtr left = parsePrefix();

        for (;;) {
            // The conditional is right-associative and binds loosest.
            if (at(TokenKind::Question) && conditionalPower >= minimumPower) {
                ++position_;
                NodePtr whenTrue = parseExpression(0);
                expect(TokenKind::Colon);
                NodePtr whenFalse = parseExpression(conditionalPower);
                left = std::make_unique<ConditionalNode>(
                    std::move(left), std::move(whenTrue), std::move(whenFalse));
                continue;
            }

            const auto power = infixPower(current().kind);
            if (!power || power->left < minimumPower) break;

            const Token op = tokens_[position_++];
            NodePtr right = parseExpression(power->right);
            left = std::make_unique<BinaryNode>(
                op.text, std::move(left), std::move(right), op.column);
        }
        return left;
    }

    NodePtr parsePrefix() {
        const Token token = current();

        switch (token.kind) {
        case TokenKind::Number:
            ++position_;
            return std::make_unique<NumberNode>(token.number);

        case TokenKind::Minus:
        case TokenKind::Plus:
        case TokenKind::Bang: {
            ++position_;
            NodePtr operand = parseExpression(unaryPower);
            return std::make_unique<UnaryNode>(token.text, std::move(operand),
                                               token.column);
        }

        case TokenKind::LeftParen: {
            ++position_;
            NodePtr inner = parseExpression(0);
            expect(TokenKind::RightParen);
            return inner;
        }

        case TokenKind::Identifier: {
            ++position_;
            if (!match(TokenKind::LeftParen)) {
                return std::make_unique<VariableNode>(token.text, token.column);
            }
            std::vector<NodePtr> arguments;
            if (!at(TokenKind::RightParen)) {
                do {
                    arguments.push_back(parseExpression(0));
                } while (match(TokenKind::Comma));
            }
            expect(TokenKind::RightParen);
            return std::make_unique<CallNode>(token.text, std::move(arguments),
                                              token.column);
        }

        default: {
            std::ostringstream out;
            out << "expected a value, found " << describe(token.kind);
            throw CalcError(out.str(), token.column);
        }
        }
    }

    std::vector<Token> tokens_;
    std::size_t        position_{0};
};

// ------------------------------------------------------------------- driver

struct Outcome {
    bool        ok{false};
    double      value{0};
    std::string tree;
    std::string error;
};

Outcome run(const std::string& source, Environment& env, bool showTree) {
    Outcome outcome;
    try {
        Parser parser(tokenise(source));
        auto statements = parser.parseProgram();
        if (statements.empty()) {
            outcome.ok = true;
            return outcome;
        }

        std::ostringstream tree;
        for (const auto& statement : statements) {
            outcome.value = statement->evaluate(env);
            if (showTree) {
                statement->print(tree);
                tree << '\n';
            }
        }
        outcome.tree = tree.str();
        outcome.ok = true;
    } catch (const CalcError& error) {
        outcome.error = error.annotate(source);
    }
    return outcome;
}

}  // namespace calc

// --------------------------------------------------------------------- main

namespace {

void session(bool showTree) {
    calc::Environment env;
    std::cout << std::setprecision(12);

    const std::vector<std::string> lines = {
        "1 + 2 * 3",
        "(1 + 2) * 3",
        "2 ^ 3 ^ 2",
        "-3 ^ 2",
        "(-3) ^ 2",
        "10 % 3 + 10 / 4",
        "x = 12; y = x / 2; x + y",
        "square(n) = n * n",
        "square(7) + square(3)",
        "hypotenuse(a, b) = sqrt(square(a) + square(b))",
        "hypotenuse(3, 4)",
        "factorial(n) = n <= 1 ? 1 : n * factorial(n - 1)",
        "factorial(12)",
        "fib(n) = n < 2 ? n : fib(n-1) + fib(n-2)",
        "fib(20)",
        "max(3, 9, 2, 7)",
        "mean(2, 4, 6, 8)",
        "clamp(120, 0, 100)",
        "x > 0 ? ln(x) : 0",
        "round(pi * 1000) / 1000",
        "1e3 + 2.5e-2",
        "!0 + !5",
        "3 < 4 == 1",
    };

    for (const auto& line : lines) {
        calc::Outcome outcome = calc::run(line, env, showTree);
        if (outcome.ok) {
            std::cout << "  " << std::left << std::setw(46) << line
                      << " = " << outcome.value << '\n';
            if (showTree && !outcome.tree.empty()) {
                std::cout << "      " << outcome.tree;
            }
        } else {
            std::cout << "  " << line << '\n' << outcome.error << '\n';
        }
    }

    std::cout << "\n--- errors ---\n";
    const std::vector<std::string> broken = {
        "1 + ",
        "2 * (3 + 4",
        "unknown + 1",
        "sqrt(1, 2)",
        "10 / 0",
        "3 @ 4",
        "nofunc(1)",
        "loop(n) = loop(n + 1)",
        "loop(1)",
    };
    for (const auto& line : broken) {
        calc::Outcome outcome = calc::run(line, env, false);
        if (outcome.ok) {
            std::cout << "  " << std::left << std::setw(24) << line
                      << " = " << outcome.value << '\n';
        } else {
            std::cout << outcome.error << '\n';
        }
    }

    std::cout << "\n--- variables now defined ---\n";
    for (const auto& [name, value] : env.snapshot()) {
        std::cout << "  " << std::left << std::setw(10) << name << value << '\n';
    }

    std::cout << "\n--- built-ins ---\n  ";
    for (const auto& name : env.builtinNames()) std::cout << name << ' ';
    std::cout << '\n';
}

void interactive() {
    calc::Environment env;
    std::string line;
    std::cout << std::setprecision(12);
    std::cout << "calc — expressions, one per line. Ctrl-D to leave.\n";

    while (std::cout << "> " && std::getline(std::cin, line)) {
        if (line.empty()) continue;
        calc::Outcome outcome = calc::run(line, env, false);
        if (outcome.ok) {
            std::cout << outcome.value << '\n';
        } else {
            std::cout << outcome.error << '\n';
        }
    }
    std::cout << '\n';
}

}  // namespace

int main(int argc, char** argv) {
    bool showTree = false;
    bool repl = false;

    for (int i = 1; i < argc; ++i) {
        const std::string flag = argv[i];
        if (flag == "-t") showTree = true;
        else if (flag == "-i") repl = true;
        else {
            std::cerr << "usage: " << argv[0] << " [-t] [-i]\n";
            return 1;
        }
    }

    if (repl) {
        interactive();
    } else {
        session(showTree);
    }
    return 0;
}
