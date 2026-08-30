// Iterators are lazy and compose; closures capture by reference, by mutable
// reference, or by value.

#[derive(Debug, Clone)]
struct Station {
    name: String,
    line: String,
    zone: u8,
    platforms: u8,
}

fn stations() -> Vec<Station> {
    [
        ("Alder Cross", "Amber", 2, 2),
        ("Quill Wharf", "Cobalt", 3, 4),
        ("Saltwick Halt", "Amber", 5, 1),
        ("Nether Gate", "Emerald", 2, 3),
        ("Bramble Fields", "Cobalt", 4, 2),
    ]
    .into_iter()
    .map(|(name, line, zone, platforms)| Station {
        name: name.to_string(),
        line: line.to_string(),
        zone,
        platforms,
    })
    .collect()
}

fn main() {
    let stations = stations();

    let inner: Vec<&str> = stations
        .iter()
        .filter(|s| s.zone <= 3)
        .map(|s| s.name.as_str())
        .collect();
    println!("inner zones: {inner:?}");

    println!("platforms: {}", stations.iter().map(|s| s.platforms as u32).sum::<u32>());
    println!("deepest: {}", stations.iter().max_by_key(|s| s.zone).unwrap().name);
    println!("any in zone 5: {}", stations.iter().any(|s| s.zone == 5));
    println!("all have platforms: {}", stations.iter().all(|s| s.platforms > 0));
    println!("count on Amber: {}", stations.iter().filter(|s| s.line == "Amber").count());
    println!("position: {:?}", stations.iter().position(|s| s.zone > 4));

    // fold and scan carry an accumulator; the second one yields it each step.
    let names = stations.iter().fold(String::new(), |mut acc, s| {
        if !acc.is_empty() {
            acc.push_str(", ");
        }
        acc.push_str(&s.name);
        acc
    });
    println!("folded: {names}");
    println!(
        "running total: {:?}",
        stations
            .iter()
            .scan(0u32, |sum, s| {
                *sum += s.platforms as u32;
                Some(*sum)
            })
            .collect::<Vec<_>>()
    );

    // zip, enumerate, chain, rev, skip, take, step_by, flat_map, windows.
    for (index, station) in stations.iter().enumerate().take(2) {
        println!("  {index}: {}", station.name);
    }
    println!("chained: {:?}", (1..3).chain(10..12).collect::<Vec<_>>());
    println!("reversed: {:?}", (1..6).rev().step_by(2).collect::<Vec<_>>());
    println!(
        "words: {:?}",
        stations.iter().flat_map(|s| s.name.split(' ')).collect::<Vec<_>>()
    );
    println!("pairs: {:?}", [1, 4, 9, 16].windows(2).collect::<Vec<_>>());

    // Laziness: nothing runs until the iterator is consumed.
    let mut pulled = 0;
    let first_three: Vec<u32> = (1..1000)
        .inspect(|_| pulled += 1)
        .filter(|n| n % 7 == 0)
        .take(3)
        .collect();
    println!("{first_three:?} after pulling {pulled} values, not 999");

    // Closures: Fn borrows, FnMut borrows mutably, FnOnce consumes.
    let threshold = 3;
    let shallow = |s: &Station| s.zone <= threshold; // Fn
    println!("shallow: {}", stations.iter().filter(|s| shallow(s)).count());

    let mut seen = Vec::new();
    let mut record = |name: &str| seen.push(name.to_string()); // FnMut
    stations.iter().take(2).for_each(|s| record(&s.name));
    println!("recorded: {seen:?}");

    let owned = String::from("consumed");
    let consume = move || owned; // FnOnce, moves the capture in
    println!("{}", consume());

    // Returning a closure needs a box or impl Trait.
    fn fare_for(base: f64) -> impl Fn(u8) -> f64 {
        move |zones| base + zones as f64 * 0.85
    }
    println!("three zones: {:.2}", fare_for(2.40)(3));
}
