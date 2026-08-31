//! A parser for a small configuration language.
//!
//! Tokeniser, recursive-descent parser, a value tree, typed lookup by path,
//! merging of two configurations, and errors that carry a line and column.
//!
//! ```text
//! rustc -O config_parser.rs -o config && ./config
//! rustc --test config_parser.rs -o config_tests && ./config_tests
//! ```
//!
//! The language looks like this:
//!
//! ```text
//! # a comment
//! name = "Northwind Ferry Cooperative"
//! founded = 2021
//! active = true
//! routes = ["HRB", "KSP", "HLW"]
//!
//! [limits]
//! passengers = 400
//! ratio = 0.86
//!
//! [limits.crew]
//! minimum = 4
//! ```
//!
//! No crates beyond the standard library. Every value below is invented.

use std::collections::btree_map::Entry;
use std::collections::BTreeMap;
use std::error::Error;
use std::fmt;

// ------------------------------------------------------------------- errors

/// Where in the source something went wrong.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Position {
    pub line: usize,
    pub column: usize,
}

impl fmt::Display for Position {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "line {}, column {}", self.line, self.column)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum ParseError {
    UnexpectedCharacter { found: char, at: Position },
    UnterminatedString { at: Position },
    BadNumber { text: String, at: Position },
    BadEscape { found: char, at: Position },
    Expected { wanted: String, found: String, at: Position },
    DuplicateKey { key: String, at: Position },
    EmptyTableName { at: Position },
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ParseError::UnexpectedCharacter { found, at } => {
                write!(f, "{at}: unexpected character {found:?}")
            }
            ParseError::UnterminatedString { at } => {
                write!(f, "{at}: unterminated string")
            }
            ParseError::BadNumber { text, at } => {
                write!(f, "{at}: {text:?} is not a number")
            }
            ParseError::BadEscape { found, at } => {
                write!(f, "{at}: unknown escape \\{found}")
            }
            ParseError::Expected { wanted, found, at } => {
                write!(f, "{at}: expected {wanted}, found {found}")
            }
            ParseError::DuplicateKey { key, at } => {
                write!(f, "{at}: {key:?} is set twice")
            }
            ParseError::EmptyTableName { at } => {
                write!(f, "{at}: a table header needs a name")
            }
        }
    }
}

impl Error for ParseError {}

/// A failed lookup, which is a different kind of problem from a failed parse.
#[derive(Debug, Clone, PartialEq)]
pub enum LookupError {
    Missing(String),
    WrongType { path: String, wanted: &'static str, found: &'static str },
}

impl fmt::Display for LookupError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LookupError::Missing(path) => write!(f, "{path} is not set"),
            LookupError::WrongType { path, wanted, found } => {
                write!(f, "{path} is {found}, wanted {wanted}")
            }
        }
    }
}

impl Error for LookupError {}

// ------------------------------------------------------------------- values

/// Everything the language can express.
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    String(String),
    Integer(i64),
    Float(f64),
    Boolean(bool),
    Array(Vec<Value>),
    Table(BTreeMap<String, Value>),
}

impl Value {
    /// The name of this variant, for an error message.
    pub fn type_name(&self) -> &'static str {
        match self {
            Value::String(_) => "a string",
            Value::Integer(_) => "an integer",
            Value::Float(_) => "a float",
            Value::Boolean(_) => "a boolean",
            Value::Array(_) => "an array",
            Value::Table(_) => "a table",
        }
    }

    /// Follow a dotted path. Borrowing rather than cloning, so a deep lookup
    /// on a large configuration costs nothing.
    pub fn get(&self, path: &str) -> Option<&Value> {
        let mut current = self;
        for segment in path.split('.') {
            match current {
                Value::Table(map) => current = map.get(segment)?,
                Value::Array(items) => {
                    let index: usize = segment.parse().ok()?;
                    current = items.get(index)?;
                }
                _ => return None,
            }
        }
        Some(current)
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::String(s) => Some(s),
            _ => None,
        }
    }

    pub fn as_integer(&self) -> Option<i64> {
        match *self {
            Value::Integer(n) => Some(n),
            _ => None,
        }
    }

    /// An integer is acceptable where a float is wanted; the reverse is not.
    pub fn as_float(&self) -> Option<f64> {
        match *self {
            Value::Float(x) => Some(x),
            Value::Integer(n) => Some(n as f64),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match *self {
            Value::Boolean(b) => Some(b),
            _ => None,
        }
    }

    pub fn as_array(&self) -> Option<&[Value]> {
        match self {
            Value::Array(items) => Some(items),
            _ => None,
        }
    }

    pub fn as_table(&self) -> Option<&BTreeMap<String, Value>> {
        match self {
            Value::Table(map) => Some(map),
            _ => None,
        }
    }

    /// Merge `other` into `self`. Tables are merged recursively; anything
    /// else in `other` replaces what is here, which is the rule that makes a
    /// per-environment override file behave the way people expect.
    pub fn merge(&mut self, other: Value) {
        match (self, other) {
            (Value::Table(mine), Value::Table(theirs)) => {
                for (key, value) in theirs {
                    // The entry API rather than get_mut/insert: looking a key
                    // up and then inserting it in the else branch holds a
                    // mutable borrow across both, which the borrow checker
                    // refuses.
                    match mine.entry(key) {
                        Entry::Occupied(mut slot) => slot.get_mut().merge(value),
                        Entry::Vacant(slot) => {
                            slot.insert(value);
                        }
                    }
                }
            }
            (slot, replacement) => *slot = replacement,
        }
    }

    /// Every leaf path in the tree, in order.
    pub fn paths(&self) -> Vec<String> {
        let mut out = Vec::new();
        self.collect_paths(String::new(), &mut out);
        out
    }

    fn collect_paths(&self, prefix: String, out: &mut Vec<String>) {
        match self {
            Value::Table(map) => {
                for (key, value) in map {
                    let path = if prefix.is_empty() {
                        key.clone()
                    } else {
                        format!("{prefix}.{key}")
                    };
                    value.collect_paths(path, out);
                }
            }
            _ if prefix.is_empty() => {}
            _ => out.push(prefix),
        }
    }
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Value::String(s) => write!(f, "{s:?}"),
            Value::Integer(n) => write!(f, "{n}"),
            Value::Float(x) => write!(f, "{x}"),
            Value::Boolean(b) => write!(f, "{b}"),
            Value::Array(items) => {
                write!(f, "[")?;
                for (index, item) in items.iter().enumerate() {
                    if index > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{item}")?;
                }
                write!(f, "]")
            }
            Value::Table(map) => {
                write!(f, "{{")?;
                for (index, (key, value)) in map.iter().enumerate() {
                    if index > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{key} = {value}")?;
                }
                write!(f, "}}")
            }
        }
    }
}

// ------------------------------------------------------------------ tokens

#[derive(Debug, Clone, PartialEq)]
enum Token {
    Key(String),
    String(String),
    Integer(i64),
    Float(f64),
    Boolean(bool),
    Equals,
    Comma,
    OpenBracket,
    CloseBracket,
    Dot,
    Newline,
}

impl Token {
    fn describe(&self) -> String {
        match self {
            Token::Key(name) => format!("the name {name:?}"),
            Token::String(_) => "a string".to_string(),
            Token::Integer(_) => "an integer".to_string(),
            Token::Float(_) => "a float".to_string(),
            Token::Boolean(_) => "a boolean".to_string(),
            Token::Equals => "'='".to_string(),
            Token::Comma => "','".to_string(),
            Token::OpenBracket => "'['".to_string(),
            Token::CloseBracket => "']'".to_string(),
            Token::Dot => "'.'".to_string(),
            Token::Newline => "the end of the line".to_string(),
        }
    }
}

#[derive(Debug, Clone)]
struct Spanned {
    token: Token,
    at: Position,
}

/// Turn source text into tokens.
///
/// The input is borrowed for the length of the call only; every token owns its
/// own data, so the result outlives the source without a lifetime parameter.
fn tokenise(source: &str) -> Result<Vec<Spanned>, ParseError> {
    let characters: Vec<char> = source.chars().collect();
    let mut tokens = Vec::new();
    let mut index = 0usize;
    let mut line = 1usize;
    let mut column = 1usize;

    let position = |line: usize, column: usize| Position { line, column };

    while index < characters.len() {
        let c = characters[index];
        let at = position(line, column);

        match c {
            ' ' | '\t' | '\r' => {
                index += 1;
                column += 1;
            }
            '\n' => {
                tokens.push(Spanned { token: Token::Newline, at });
                index += 1;
                line += 1;
                column = 1;
            }
            '#' => {
                while index < characters.len() && characters[index] != '\n' {
                    index += 1;
                    column += 1;
                }
            }
            '=' => {
                tokens.push(Spanned { token: Token::Equals, at });
                index += 1;
                column += 1;
            }
            ',' => {
                tokens.push(Spanned { token: Token::Comma, at });
                index += 1;
                column += 1;
            }
            '[' => {
                tokens.push(Spanned { token: Token::OpenBracket, at });
                index += 1;
                column += 1;
            }
            ']' => {
                tokens.push(Spanned { token: Token::CloseBracket, at });
                index += 1;
                column += 1;
            }
            '.' => {
                tokens.push(Spanned { token: Token::Dot, at });
                index += 1;
                column += 1;
            }
            '"' => {
                index += 1;
                column += 1;
                let mut text = String::new();

                loop {
                    if index >= characters.len() {
                        return Err(ParseError::UnterminatedString { at });
                    }
                    match characters[index] {
                        '"' => {
                            index += 1;
                            column += 1;
                            break;
                        }
                        '\\' => {
                            index += 1;
                            column += 1;
                            if index >= characters.len() {
                                return Err(ParseError::UnterminatedString { at });
                            }
                            let escape = characters[index];
                            let decoded = match escape {
                                'n' => '\n',
                                't' => '\t',
                                'r' => '\r',
                                '\\' => '\\',
                                '"' => '"',
                                other => {
                                    return Err(ParseError::BadEscape {
                                        found: other,
                                        at: position(line, column),
                                    })
                                }
                            };
                            text.push(decoded);
                            index += 1;
                            column += 1;
                        }
                        '\n' => return Err(ParseError::UnterminatedString { at }),
                        other => {
                            text.push(other);
                            index += 1;
                            column += 1;
                        }
                    }
                }

                tokens.push(Spanned { token: Token::String(text), at });
            }
            c if c.is_ascii_digit() || c == '-' || c == '+' => {
                let start = index;
                let start_column = column;
                if c == '-' || c == '+' {
                    index += 1;
                    column += 1;
                }
                let mut seen_dot = false;
                let mut seen_exponent = false;

                while index < characters.len() {
                    let d = characters[index];
                    if d.is_ascii_digit() || d == '_' {
                        index += 1;
                        column += 1;
                    } else if d == '.' && !seen_dot && !seen_exponent {
                        seen_dot = true;
                        index += 1;
                        column += 1;
                    } else if (d == 'e' || d == 'E') && !seen_exponent {
                        seen_exponent = true;
                        index += 1;
                        column += 1;
                        if index < characters.len()
                            && (characters[index] == '-' || characters[index] == '+')
                        {
                            index += 1;
                            column += 1;
                        }
                    } else {
                        break;
                    }
                }

                let text: String = characters[start..index]
                    .iter()
                    .filter(|d| **d != '_')
                    .collect();
                let at = position(line, start_column);

                let token = if seen_dot || seen_exponent {
                    Token::Float(text.parse::<f64>().map_err(|_| ParseError::BadNumber {
                        text: text.clone(),
                        at,
                    })?)
                } else {
                    Token::Integer(text.parse::<i64>().map_err(|_| ParseError::BadNumber {
                        text: text.clone(),
                        at,
                    })?)
                };
                tokens.push(Spanned { token, at });
            }
            c if c.is_alphabetic() || c == '_' => {
                let start = index;
                while index < characters.len()
                    && (characters[index].is_alphanumeric()
                        || characters[index] == '_'
                        || characters[index] == '-')
                {
                    index += 1;
                    column += 1;
                }
                let word: String = characters[start..index].iter().collect();
                let token = match word.as_str() {
                    "true" => Token::Boolean(true),
                    "false" => Token::Boolean(false),
                    _ => Token::Key(word),
                };
                tokens.push(Spanned { token, at });
            }
            other => {
                return Err(ParseError::UnexpectedCharacter { found: other, at });
            }
        }
    }

    Ok(tokens)
}

// ------------------------------------------------------------------ parser

struct Parser {
    tokens: Vec<Spanned>,
    index: usize,
}

impl Parser {
    fn new(tokens: Vec<Spanned>) -> Self {
        Parser { tokens, index: 0 }
    }

    fn peek(&self) -> Option<&Spanned> {
        self.tokens.get(self.index)
    }

    fn position(&self) -> Position {
        self.tokens
            .get(self.index)
            .map(|s| s.at)
            .or_else(|| self.tokens.last().map(|s| s.at))
            .unwrap_or(Position { line: 1, column: 1 })
    }

    fn skip_newlines(&mut self) {
        while matches!(self.peek().map(|s| &s.token), Some(Token::Newline)) {
            self.index += 1;
        }
    }

    fn take(&mut self) -> Option<Spanned> {
        let value = self.tokens.get(self.index).cloned();
        if value.is_some() {
            self.index += 1;
        }
        value
    }

    fn expect(&mut self, wanted: Token) -> Result<(), ParseError> {
        let at = self.position();
        // Cloning the token first ends the borrow of self, so the arm below
        // is free to advance the index.
        let found = self.peek().map(|spanned| spanned.token.clone());

        match found {
            Some(token) if token == wanted => {
                self.index += 1;
                Ok(())
            }
            Some(token) => Err(ParseError::Expected {
                wanted: wanted.describe(),
                found: token.describe(),
                at,
            }),
            None => Err(ParseError::Expected {
                wanted: wanted.describe(),
                found: "the end of the file".to_string(),
                at,
            }),
        }
    }

    /// Parse the whole document into a root table.
    fn parse(&mut self) -> Result<Value, ParseError> {
        let mut root: BTreeMap<String, Value> = BTreeMap::new();
        // Where the next `key = value` goes. Empty means the root table.
        let mut section: Vec<String> = Vec::new();

        loop {
            self.skip_newlines();
            let Some(spanned) = self.peek().cloned() else { break };

            match spanned.token {
                Token::OpenBracket => {
                    self.index += 1;
                    section = self.parse_table_header()?;
                    table_at(&mut root, &section, spanned.at)?;
                }
                Token::Key(_) | Token::String(_) => {
                    let (key, value, at) = self.parse_assignment()?;
                    let table = table_at(&mut root, &section, at)?;
                    if table.contains_key(&key) {
                        return Err(ParseError::DuplicateKey { key, at });
                    }
                    table.insert(key, value);
                }
                other => {
                    return Err(ParseError::Expected {
                        wanted: "a key or a table header".to_string(),
                        found: other.describe(),
                        at: spanned.at,
                    })
                }
            }
        }

        Ok(Value::Table(root))
    }

    fn parse_table_header(&mut self) -> Result<Vec<String>, ParseError> {
        let at = self.position();

        if matches!(self.peek().map(|s| &s.token), Some(Token::CloseBracket)) {
            self.index += 1;
            return Err(ParseError::EmptyTableName { at });
        }

        let mut path = Vec::new();

        loop {
            match self.take() {
                Some(Spanned { token: Token::Key(name), .. }) => path.push(name),
                Some(Spanned { token: Token::String(name), .. }) => path.push(name),
                Some(Spanned { token, at }) => {
                    return Err(ParseError::Expected {
                        wanted: "a table name".to_string(),
                        found: token.describe(),
                        at,
                    })
                }
                None => {
                    return Err(ParseError::Expected {
                        wanted: "a table name".to_string(),
                        found: "the end of the file".to_string(),
                        at,
                    })
                }
            }

            match self.peek().map(|s| s.token.clone()) {
                Some(Token::Dot) => {
                    self.index += 1;
                }
                _ => break,
            }
        }

        self.expect(Token::CloseBracket)?;
        Ok(path)
    }

    fn parse_assignment(&mut self) -> Result<(String, Value, Position), ParseError> {
        let at = self.position();
        let key = match self.take() {
            Some(Spanned { token: Token::Key(name), .. }) => name,
            Some(Spanned { token: Token::String(name), .. }) => name,
            Some(Spanned { token, at }) => {
                return Err(ParseError::Expected {
                    wanted: "a key".to_string(),
                    found: token.describe(),
                    at,
                })
            }
            None => {
                return Err(ParseError::Expected {
                    wanted: "a key".to_string(),
                    found: "the end of the file".to_string(),
                    at,
                })
            }
        };

        self.expect(Token::Equals)?;
        let value = self.parse_value()?;
        Ok((key, value, at))
    }

    fn parse_value(&mut self) -> Result<Value, ParseError> {
        let at = self.position();
        match self.take() {
            Some(Spanned { token: Token::String(text), .. }) => Ok(Value::String(text)),
            Some(Spanned { token: Token::Integer(n), .. }) => Ok(Value::Integer(n)),
            Some(Spanned { token: Token::Float(x), .. }) => Ok(Value::Float(x)),
            Some(Spanned { token: Token::Boolean(b), .. }) => Ok(Value::Boolean(b)),
            Some(Spanned { token: Token::OpenBracket, .. }) => self.parse_array(),
            Some(Spanned { token, at }) => Err(ParseError::Expected {
                wanted: "a value".to_string(),
                found: token.describe(),
                at,
            }),
            None => Err(ParseError::Expected {
                wanted: "a value".to_string(),
                found: "the end of the file".to_string(),
                at,
            }),
        }
    }

    fn parse_array(&mut self) -> Result<Value, ParseError> {
        let mut items = Vec::new();

        loop {
            self.skip_newlines();
            if matches!(self.peek().map(|s| &s.token), Some(Token::CloseBracket)) {
                self.index += 1;
                break;
            }

            items.push(self.parse_value()?);
            self.skip_newlines();

            match self.peek().map(|s| s.token.clone()) {
                Some(Token::Comma) => {
                    self.index += 1;
                }
                Some(Token::CloseBracket) => {
                    self.index += 1;
                    break;
                }
                Some(other) => {
                    return Err(ParseError::Expected {
                        wanted: "',' or ']'".to_string(),
                        found: other.describe(),
                        at: self.position(),
                    })
                }
                None => {
                    return Err(ParseError::Expected {
                        wanted: "']'".to_string(),
                        found: "the end of the file".to_string(),
                        at: self.position(),
                    })
                }
            }
        }

        Ok(Value::Array(items))
    }
}

/// Walk down to the table a section header names, creating tables on the way
/// and refusing to descend through anything that is not one.
///
/// Written recursively rather than as a loop that reassigns a `&mut`: each
/// call borrows from the one above it, which is a shape the borrow checker
/// accepts without argument.
fn table_at<'a>(
    root: &'a mut BTreeMap<String, Value>,
    path: &[String],
    at: Position,
) -> Result<&'a mut BTreeMap<String, Value>, ParseError> {
    let Some((first, rest)) = path.split_first() else {
        return Ok(root);
    };

    let entry = root
        .entry(first.clone())
        .or_insert_with(|| Value::Table(BTreeMap::new()));

    match entry {
        Value::Table(map) => table_at(map, rest, at),
        other => Err(ParseError::Expected {
            wanted: "a table".to_string(),
            found: other.type_name().to_string(),
            at,
        }),
    }
}

/// Parse configuration text.
pub fn parse(source: &str) -> Result<Value, ParseError> {
    let tokens = tokenise(source)?;
    Parser::new(tokens).parse()
}

// ------------------------------------------------------------ typed lookup

/// Typed access to a configuration, with an error that names the path.
pub struct Config {
    root: Value,
}

impl Config {
    pub fn parse(source: &str) -> Result<Self, ParseError> {
        Ok(Config { root: parse(source)? })
    }

    pub fn root(&self) -> &Value {
        &self.root
    }

    fn require(&self, path: &str) -> Result<&Value, LookupError> {
        self.root
            .get(path)
            .ok_or_else(|| LookupError::Missing(path.to_string()))
    }

    pub fn string(&self, path: &str) -> Result<&str, LookupError> {
        let value = self.require(path)?;
        value.as_str().ok_or(LookupError::WrongType {
            path: path.to_string(),
            wanted: "a string",
            found: value.type_name(),
        })
    }

    pub fn integer(&self, path: &str) -> Result<i64, LookupError> {
        let value = self.require(path)?;
        value.as_integer().ok_or(LookupError::WrongType {
            path: path.to_string(),
            wanted: "an integer",
            found: value.type_name(),
        })
    }

    pub fn float(&self, path: &str) -> Result<f64, LookupError> {
        let value = self.require(path)?;
        value.as_float().ok_or(LookupError::WrongType {
            path: path.to_string(),
            wanted: "a float",
            found: value.type_name(),
        })
    }

    pub fn boolean(&self, path: &str) -> Result<bool, LookupError> {
        let value = self.require(path)?;
        value.as_bool().ok_or(LookupError::WrongType {
            path: path.to_string(),
            wanted: "a boolean",
            found: value.type_name(),
        })
    }

    pub fn strings(&self, path: &str) -> Result<Vec<&str>, LookupError> {
        let value = self.require(path)?;
        let items = value.as_array().ok_or(LookupError::WrongType {
            path: path.to_string(),
            wanted: "an array",
            found: value.type_name(),
        })?;

        items
            .iter()
            .enumerate()
            .map(|(index, item)| {
                item.as_str().ok_or(LookupError::WrongType {
                    path: format!("{path}.{index}"),
                    wanted: "a string",
                    found: item.type_name(),
                })
            })
            .collect()
    }

    /// A value with a fallback, which is the common case in real code.
    pub fn integer_or(&self, path: &str, fallback: i64) -> i64 {
        self.integer(path).unwrap_or(fallback)
    }

    /// Layer another configuration over this one.
    pub fn overlay(&mut self, source: &str) -> Result<(), ParseError> {
        let other = parse(source)?;
        self.root.merge(other);
        Ok(())
    }
}

// -------------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_scalars() {
        let config = Config::parse(
            r#"
            name = "Halloway"
            count = 42
            ratio = 0.5
            active = true
            "#,
        )
        .expect("should parse");

        assert_eq!(config.string("name").unwrap(), "Halloway");
        assert_eq!(config.integer("count").unwrap(), 42);
        assert_eq!(config.float("ratio").unwrap(), 0.5);
        assert!(config.boolean("active").unwrap());
    }

    #[test]
    fn an_integer_reads_as_a_float() {
        let config = Config::parse("n = 7").unwrap();
        assert_eq!(config.float("n").unwrap(), 7.0);
        assert!(config.string("n").is_err());
    }

    #[test]
    fn nested_tables() {
        let config = Config::parse(
            r#"
            [limits]
            passengers = 400
            [limits.crew]
            minimum = 4
            "#,
        )
        .unwrap();

        assert_eq!(config.integer("limits.passengers").unwrap(), 400);
        assert_eq!(config.integer("limits.crew.minimum").unwrap(), 4);
    }

    #[test]
    fn arrays_and_indexing() {
        let config = Config::parse(r#"routes = ["HRB", "KSP", "HLW"]"#).unwrap();
        assert_eq!(config.strings("routes").unwrap(), vec!["HRB", "KSP", "HLW"]);
        assert_eq!(config.string("routes.1").unwrap(), "KSP");
        assert!(config.string("routes.9").is_err());
    }

    #[test]
    fn merging_prefers_the_overlay() {
        let mut config = Config::parse(
            r#"
            name = "base"
            [limits]
            passengers = 400
            crew = 4
            "#,
        )
        .unwrap();

        config
            .overlay(
                r#"
                [limits]
                passengers = 200
                "#,
            )
            .unwrap();

        assert_eq!(config.string("name").unwrap(), "base");
        assert_eq!(config.integer("limits.passengers").unwrap(), 200);
        assert_eq!(config.integer("limits.crew").unwrap(), 4);
    }

    #[test]
    fn duplicate_keys_are_refused() {
        let error = Config::parse("a = 1\na = 2").unwrap_err();
        assert!(matches!(error, ParseError::DuplicateKey { .. }));
    }

    #[test]
    fn errors_carry_a_position() {
        let error = parse("a = 1\nb = @").unwrap_err();
        match error {
            ParseError::UnexpectedCharacter { found, at } => {
                assert_eq!(found, '@');
                assert_eq!(at.line, 2);
            }
            other => panic!("wrong error: {other}"),
        }
    }

    #[test]
    fn escapes_are_decoded() {
        let config = Config::parse(r#"s = "a\tb\nc\"d""#).unwrap();
        assert_eq!(config.string("s").unwrap(), "a\tb\nc\"d");
    }

    #[test]
    fn underscores_in_numbers() {
        let config = Config::parse("n = 1_000_000").unwrap();
        assert_eq!(config.integer("n").unwrap(), 1_000_000);
    }
}

// --------------------------------------------------------------------- main

const SAMPLE: &str = r#"
# The cooperative's configuration. Every value here is invented.

name        = "Northwind Ferry Cooperative"
founded     = 2021
active      = true
recovery    = 1.05
routes      = ["HRB", "KSP", "HLW", "NCR"]
capacities  = [380, 240, 120, 90]

[limits]
passengers      = 400
bookings-per-ip = 20
ratio           = 0.86

[limits.crew]
minimum   = 4
preferred = 6
roles     = ["master", "mate", "engineer", "deckhand"]

[timetable]
first  = "06:15"
last   = "23:00"
"interval-minutes" = 20

[timetable.exceptions]
sunday  = "reduced"
holiday = "sunday"

[storage]
path       = "/srv/northwind"
max-size   = 5_000_000
compress   = true
retain-for = 90
"#;

const OVERRIDE: &str = r#"
# Production overrides. Only what differs is repeated.

[limits]
passengers = 360

[limits.crew]
minimum = 5

[storage]
path = "/mnt/fast/northwind"

[monitoring]
enabled  = true
interval = 30
"#;

const BROKEN: &[&str] = &[
    "a = ",
    "a 1",
    "= 1",
    "a = @",
    "a = \"unterminated",
    "a = [1, 2",
    "a = 1\na = 2",
    "[]\nb = 1",
    "a = \"bad \\q escape\"",
    "a = 1\n[a]\nb = 2",
];

fn main() {
    println!("--- parsing ---");
    let mut config = match Config::parse(SAMPLE) {
        Ok(config) => config,
        Err(error) => {
            eprintln!("the sample failed to parse: {error}");
            std::process::exit(1);
        }
    };

    let paths = config.root().paths();
    println!("  {} leaf value(s)", paths.len());
    for path in paths.iter().take(8) {
        println!("    {path:<28} {}", config.root().get(path).unwrap());
    }
    println!("    ...");

    println!("\n--- typed access ---");
    println!("  name          {}", config.string("name").unwrap());
    println!("  founded       {}", config.integer("founded").unwrap());
    println!("  recovery      {:.2}", config.float("recovery").unwrap());
    println!("  active        {}", config.boolean("active").unwrap());
    println!("  routes        {:?}", config.strings("routes").unwrap());
    println!("  crew roles    {:?}", config.strings("limits.crew.roles").unwrap());
    println!("  second route  {}", config.string("routes.1").unwrap());
    println!(
        "  interval      {}",
        config.integer("timetable.interval-minutes").unwrap()
    );

    println!("\n--- lookups that fail ---");
    let failures = [
        ("nothing.here", "missing"),
        ("name", "wrong type"),
        ("routes.99", "out of range"),
        ("capacities", "array of the wrong element type"),
    ];
    for (path, why) in failures {
        let result: Result<i64, LookupError> = if path == "capacities" {
            config.strings(path).map(|values| values.len() as i64)
        } else {
            config.integer(path)
        };
        match result {
            Ok(value) => println!("  {path:<16} unexpectedly ok: {value}"),
            Err(error) => println!("  {path:<16} {error}   [{why}]"),
        }
    }

    println!("\n--- walking a sub-table ---");
    if let Some(limits) = config.root().get("limits").and_then(Value::as_table) {
        println!("  limits has {} entr(y/ies):", limits.len());
        for (key, value) in limits {
            println!("    {key:<12} {value}");
        }
    }

    println!("\n--- defaults ---");
    println!(
        "  limits.retries is unset, so the fallback is used: {}",
        config.integer_or("limits.retries", 3)
    );

    println!("\n--- overlaying production settings ---");
    println!(
        "  before: passengers {}, crew {}, path {}",
        config.integer("limits.passengers").unwrap(),
        config.integer("limits.crew.minimum").unwrap(),
        config.string("storage.path").unwrap()
    );
    config.overlay(OVERRIDE).expect("the override should parse");
    println!(
        "  after:  passengers {}, crew {}, path {}",
        config.integer("limits.passengers").unwrap(),
        config.integer("limits.crew.minimum").unwrap(),
        config.string("storage.path").unwrap()
    );
    println!(
        "  untouched keys survive: crew.preferred is still {}",
        config.integer("limits.crew.preferred").unwrap()
    );
    println!(
        "  new sections arrive whole: monitoring.interval is {}",
        config.integer("monitoring.interval").unwrap()
    );

    println!("\n--- input the parser refuses ---");
    for source in BROKEN {
        let shown = source.replace('\n', "\\n");
        match parse(source) {
            Ok(_) => println!("  {shown:<26} ACCEPTED, which is a bug"),
            Err(error) => println!("  {shown:<26} {error}"),
        }
    }
}
