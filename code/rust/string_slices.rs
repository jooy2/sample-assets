// String is an owned, growable UTF-8 buffer; &str is a borrowed view into
// one. Indexing is by byte, so slicing has to land on a character boundary.

fn shout(text: &str) -> String {
    text.to_uppercase()
}

fn main() {
    let owned: String = String::from("Alder Cross");
    let borrowed: &str = "Quill Wharf"; // a string literal is a &'static str
    let view: &str = &owned[..5];

    println!("{owned} / {borrowed} / {view}");
    println!("&String coerces to &str: {}", shout(&owned));

    // Growing a String.
    let mut buffer = String::with_capacity(32);
    buffer.push_str("zone ");
    buffer.push('2');
    buffer += " (central)";
    println!("{buffer} — len {} cap {}", buffer.len(), buffer.capacity());

    // format! builds without mutating anything.
    println!("{}", format!("{:-<20}|{:>8.2}", "Alder Cross", 3.4));

    let line = "Alder Cross,Amber,2,true";
    let fields: Vec<&str> = line.split(',').collect();
    println!("{} fields, last {:?}", fields.len(), fields.last());
    println!("joined: {}", fields[..3].join(" | "));

    println!("contains: {}", line.contains("Amber"));
    println!("starts/ends: {} {}", line.starts_with("Alder"), line.ends_with("true"));
    println!("find: {:?}", line.find(','));
    println!("replace: {}", line.replace(',', "; "));
    println!("trim: [{}]", "   spaced out   ".trim());
    println!("strip prefix: {:?}", line.strip_prefix("Alder "));
    println!("split_once: {:?}", line.split_once(','));
    println!("lines: {:?}", "a\nb\nc".lines().collect::<Vec<_>>());
    println!("repeat: {}", "-".repeat(24));

    // Bytes and characters are not the same thing.
    let unicode = "café naïve";
    println!("bytes {} vs chars {}", unicode.len(), unicode.chars().count());
    println!("first four chars: {}", unicode.chars().take(4).collect::<String>());
    println!("char_indices: {:?}", unicode.char_indices().take(5).collect::<Vec<_>>());

    // Slicing on a byte index inside a character panics, so use the
    // character-aware helpers instead.
    println!("is 3 a boundary: {}", unicode.is_char_boundary(3));
    println!("is 4 a boundary: {}", unicode.is_char_boundary(4));
    println!(
        "safe slice: {:?}",
        unicode.char_indices().nth(4).map(|(at, _)| &unicode[..at])
    );

    // Parsing and converting.
    let zone: u8 = "2".parse().expect("a number");
    println!("parsed {zone}, back to a string {:?}", zone.to_string());
    println!("bad parse: {:?}", "east".parse::<u8>().is_err());

    // Chars have their own predicates.
    let title: String = "quill moor"
        .split(' ')
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ");
    println!("title case: {title}");

    let slug: String = line
        .to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect();
    println!("slug: {}", slug.trim_matches('-'));
}
