// Option is "a value or nothing"; Result is "a value or an error". Rust has
// no null and no exceptions, so these two carry the whole load.

use std::collections::HashMap;

fn zone_of(network: &HashMap<&str, u8>, station: &str) -> Option<u8> {
    network.get(station).copied()
}

fn parse_zone(raw: &str) -> Result<u8, String> {
    let zone: u8 = raw.parse().map_err(|_| format!("{raw:?} is not a number"))?;

    if !(1..=6).contains(&zone) {
        return Err(format!("zone {zone} is outside 1-6"));
    }
    Ok(zone)
}

// The ? operator returns early on None, so a chain stays flat.
fn first_word_length(text: &str) -> Option<usize> {
    let first = text.split_whitespace().next()?;
    Some(first.len())
}

fn main() {
    let network = HashMap::from([("Alder Cross", 2u8), ("Quill Wharf", 3), ("Saltwick Halt", 5)]);

    for station in ["Quill Wharf", "Nether Gate"] {
        match zone_of(&network, station) {
            Some(zone) => println!("{station} is in zone {zone}"),
            None => println!("{station} is not on the network"),
        }
    }

    // The combinators avoid a match for the common cases.
    println!("fallback: {}", zone_of(&network, "Nether Gate").unwrap_or(0));
    println!("computed fallback: {}", zone_of(&network, "Nether Gate").unwrap_or_else(|| 1));
    println!("mapped: {:?}", zone_of(&network, "Alder Cross").map(|zone| zone * 10));
    println!("filtered: {:?}", zone_of(&network, "Alder Cross").filter(|&z| z > 4));
    println!("chained: {:?}", zone_of(&network, "Alder Cross").and_then(|z| z.checked_mul(100)));
    println!("or: {:?}", zone_of(&network, "Nether Gate").or(Some(1)));
    println!("is_some: {}", zone_of(&network, "Quill Wharf").is_some());

    println!("first word: {:?}", first_word_length("Alder Cross"));
    println!("empty: {:?}", first_word_length("   "));

    for raw in ["3", "9", "east"] {
        match parse_zone(raw) {
            Ok(zone) => println!("{raw:<6} -> zone {zone}"),
            Err(message) => println!("{raw:<6} -> {message}"),
        }
    }

    // Result has the same combinators, plus ok() to drop the error.
    println!("ok(): {:?}", parse_zone("9").ok());
    println!("unwrap_or: {}", parse_zone("east").unwrap_or(1));
    println!("mapped: {:?}", parse_zone("4").map(|zone| zone * 2));
    println!("map_err: {:?}", parse_zone("9").map_err(|e| e.to_uppercase()));

    // Collecting into Result<Vec<_>, _> stops at the first error.
    let all: Result<Vec<u8>, String> = ["1", "2", "3"].iter().map(|r| parse_zone(r)).collect();
    println!("all good: {all:?}");

    let some_bad: Result<Vec<u8>, String> = ["1", "nine", "3"].iter().map(|r| parse_zone(r)).collect();
    println!("first failure wins: {some_bad:?}");

    // Option<Vec<_>> works the same way, and flatten drops the Nones.
    let zones: Vec<u8> = ["Alder Cross", "Nether Gate", "Quill Wharf"]
        .iter()
        .filter_map(|s| zone_of(&network, s))
        .collect();
    println!("filter_map kept {zones:?}");
}
