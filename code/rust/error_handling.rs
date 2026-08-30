// A custom error type, the From conversions that make `?` work, and the
// std::error::Error trait — all without an external crate.

use std::error::Error;
use std::fmt;
use std::num::ParseIntError;

#[derive(Debug)]
enum ConfigError {
    NotFound { key: String },
    Invalid { key: String, source: ParseIntError },
    OutOfRange { key: String, value: i64 },
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::NotFound { key } => write!(f, "{key} is missing"),
            ConfigError::Invalid { key, .. } => write!(f, "{key} is not a number"),
            ConfigError::OutOfRange { key, value } => write!(f, "{key}={value} is out of range"),
        }
    }
}

// Implementing Error makes the type usable as Box<dyn Error> and gives it
// a source chain.
impl Error for ConfigError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            ConfigError::Invalid { source, .. } => Some(source),
            _ => None,
        }
    }
}

struct Config {
    values: Vec<(String, String)>,
}

impl Config {
    fn get(&self, key: &str) -> Result<&str, ConfigError> {
        self.values
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value.as_str())
            .ok_or_else(|| ConfigError::NotFound { key: key.to_string() })
    }

    fn get_int(&self, key: &str, range: std::ops::RangeInclusive<i64>) -> Result<i64, ConfigError> {
        let raw = self.get(key)?; // ? propagates ConfigError unchanged

        let value: i64 = raw.parse().map_err(|source| ConfigError::Invalid {
            key: key.to_string(),
            source,
        })?;

        if !range.contains(&value) {
            return Err(ConfigError::OutOfRange { key: key.to_string(), value });
        }
        Ok(value)
    }
}

// Box<dyn Error> accepts any error type, which suits a main or a top-level
// handler where the exact type no longer matters.
fn load(config: &Config) -> Result<(i64, i64), Box<dyn Error>> {
    let port = config.get_int("port", 1..=65535)?;
    let workers = config.get_int("workers", 1..=64)?;
    Ok((port, workers))
}

fn main() {
    let config = Config {
        values: vec![
            (String::from("port"), String::from("8080")),
            (String::from("workers"), String::from("4")),
            (String::from("timeout"), String::from("soon")),
            (String::from("retries"), String::from("900")),
        ],
    };

    match load(&config) {
        Ok((port, workers)) => println!("listening on {port} with {workers} workers"),
        Err(error) => println!("failed: {error}"),
    }

    for key in ["timeout", "retries", "missing"] {
        match config.get_int(key, 1..=64) {
            Ok(value) => println!("{key:<9} = {value}"),
            Err(error) => {
                print!("{key:<9} ! {error}");
                // Walk the chain of causes.
                let mut source = error.source();
                while let Some(cause) = source {
                    print!(" (caused by: {cause})");
                    source = cause.source();
                }
                println!();
            }
        }
    }

    // Panics are for bugs, not for expected failures. catch_unwind is the
    // exception, and is rarely the right answer.
    let outcome = std::panic::catch_unwind(|| {
        let empty: Vec<u8> = Vec::new();
        empty[0]
    });
    println!("a panic was caught: {}", outcome.is_err());
}
