// The standard collections: Vec, HashMap, BTreeMap, HashSet, and VecDeque.

use std::collections::{BTreeMap, HashMap, HashSet, VecDeque};

fn main() {
    // Vec: a growable array.
    let mut zones = vec![2, 3, 5, 2, 4];
    zones.push(1);
    zones.sort();
    zones.dedup();
    println!("{zones:?} len {} cap {}", zones.len(), zones.capacity());
    println!("first {:?}, last {:?}", zones.first(), zones.last());
    println!("contains 4: {}", zones.contains(&4));
    println!("binary search for 3: {:?}", zones.binary_search(&3));
    zones.retain(|&zone| zone > 1);
    println!("after retain: {zones:?}");

    // HashMap: unordered, and the entry API avoids a double lookup.
    let mut network: HashMap<&str, u8> = HashMap::new();
    network.insert("Alder Cross", 2);
    network.insert("Quill Wharf", 3);
    network.insert("Saltwick Halt", 5);

    println!("get: {:?}", network.get("Quill Wharf"));
    println!("missing: {:?}", network.get("Nether Gate"));
    println!("with a default: {}", network.get("Nether Gate").copied().unwrap_or(1));

    *network.entry("Alder Cross").or_insert(0) += 10;
    network.entry("Nether Gate").or_insert(2);
    println!("after entry(): {:?}", network.get("Alder Cross"));

    // Counting with the entry API.
    let mut counts: HashMap<char, usize> = HashMap::new();
    for character in "mississippi".chars() {
        *counts.entry(character).or_default() += 1;
    }
    let mut tally: Vec<_> = counts.into_iter().collect();
    tally.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    println!("tally: {tally:?}");

    // Grouping into a map of vectors.
    let stations = [("Alder Cross", "Amber"), ("Saltwick Halt", "Amber"), ("Quill Wharf", "Cobalt")];
    let mut by_line: HashMap<&str, Vec<&str>> = HashMap::new();
    for (name, line) in stations {
        by_line.entry(line).or_default().push(name);
    }
    println!("grouped: {by_line:?}");

    // BTreeMap keeps its keys sorted, and supports range queries.
    let ordered: BTreeMap<u8, &str> = BTreeMap::from([(3, "suburban"), (1, "central"), (5, "outer")]);
    println!("in key order: {ordered:?}");
    println!("range 2..=5: {:?}", ordered.range(2..=5).collect::<Vec<_>>());
    println!("first: {:?}, last: {:?}", ordered.first_key_value(), ordered.last_key_value());

    // HashSet: membership and set algebra.
    let amber: HashSet<&str> = HashSet::from(["Alder Cross", "Saltwick Halt"]);
    let step_free: HashSet<&str> = HashSet::from(["Alder Cross", "Nether Gate"]);

    println!("intersection: {:?}", amber.intersection(&step_free).collect::<Vec<_>>());
    println!("union: {}", amber.union(&step_free).count());
    println!("difference: {:?}", amber.difference(&step_free).collect::<Vec<_>>());
    println!("disjoint: {}", amber.is_disjoint(&step_free));

    // VecDeque: cheap push and pop at both ends.
    let mut queue: VecDeque<&str> = VecDeque::from(["Alder Cross", "Quill Wharf"]);
    queue.push_front("Nether Gate");
    queue.push_back("Saltwick Halt");
    println!("queue: {queue:?}");
    println!("popped {:?} and {:?}", queue.pop_front(), queue.pop_back());

    // Collecting into whichever collection the type annotation asks for.
    let squares: Vec<u32> = (1..=5).map(|n| n * n).collect();
    let lookup: HashMap<u32, u32> = (1..=5).map(|n| (n, n * n)).collect();
    println!("{squares:?} / {} entries", lookup.len());
}
