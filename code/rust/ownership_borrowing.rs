// Ownership, moves, and borrowing: the rules the borrow checker enforces.

fn takes_ownership(text: String) -> usize {
    text.len() // `text` is dropped here
}

fn borrows(text: &String) -> usize {
    text.len() // the caller keeps ownership
}

fn borrows_mutably(text: &mut String) {
    text.push_str(" Station");
}

fn main() {
    // Assignment moves for types that are not Copy.
    let name = String::from("Alder Cross");
    let moved = name;
    // println!("{name}");  // would not compile: `name` was moved
    println!("moved: {moved}");

    // Integers are Copy, so assignment duplicates instead of moving.
    let zone = 2;
    let copied = zone;
    println!("both still usable: {zone} and {copied}");

    // A clone is an explicit deep copy.
    let original = String::from("Quill Wharf");
    let clone = original.clone();
    println!("clone: {clone}, original still: {original}");

    // Passing by value moves; passing a reference borrows.
    let owned = String::from("Saltwick Halt");
    println!("length by value: {}", takes_ownership(owned));
    // owned is gone here

    let kept = String::from("Nether Gate");
    println!("length by reference: {}, still have {kept}", borrows(&kept));

    let mut growing = String::from("Bramble Fields");
    borrows_mutably(&mut growing);
    println!("after a mutable borrow: {growing}");

    // Many shared borrows, or exactly one mutable borrow, never both.
    let first = &growing;
    let second = &growing;
    println!("two shared borrows: {} and {}", first.len(), second.len());

    let exclusive = &mut growing;
    exclusive.push('!');
    println!("one exclusive borrow: {exclusive}");

    // A slice borrows part of a collection without copying it.
    let stations = vec![
        String::from("Alder Cross"),
        String::from("Quill Wharf"),
        String::from("Saltwick Halt"),
    ];
    let window: &[String] = &stations[1..];
    println!("slice of {} borrowed from {}", window.len(), stations.len());

    // Values are dropped at the end of their scope, in reverse order.
    {
        let _inner = String::from("dropped at the closing brace");
        println!("inside the scope");
    }
    println!("outside it again");

    // Shadowing rebinds a name to a new value, which is not mutation.
    let count = 5;
    let count = count * 2;
    let count = format!("{count} platforms");
    println!("shadowed three times: {count}");
}
