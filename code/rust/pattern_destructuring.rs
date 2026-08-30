// Patterns work in let, function arguments, for loops, if let, while let,
// and match — not only in match.

#[derive(Debug)]
struct Reading {
    device: String,
    celsius: f64,
    battery: u8,
}

#[derive(Debug)]
enum Event {
    Reading { device: String, celsius: f64 },
    Offline(String),
    Heartbeat,
}

// Destructuring in a parameter list.
fn distance((x1, y1): (i32, i32), (x2, y2): (i32, i32)) -> f64 {
    (((x2 - x1).pow(2) + (y2 - y1).pow(2)) as f64).sqrt()
}

fn main() {
    // let with a tuple, an array, and a struct.
    let (hours, minutes, seconds) = (2, 30, 45);
    println!("{hours}h {minutes}m {seconds}s");

    let [first, .., last] = [1, 2, 3, 4, 5];
    println!("first {first}, last {last}");

    let Reading { device, celsius, .. } = Reading {
        device: String::from("SNS-01"),
        celsius: 21.4,
        battery: 88,
    };
    println!("{device} at {celsius}C");

    // Renaming while destructuring.
    let Reading { device: id, battery: charge, .. } = Reading {
        device: String::from("SNS-04"),
        celsius: 31.2,
        battery: 74,
    };
    println!("{id} has {charge}% left");

    println!("distance: {:.2}", distance((0, 0), (3, 4)));

    // for loops destructure each item.
    let zones = [("Alder Cross", 2), ("Quill Wharf", 3)];
    for (name, zone) in zones {
        println!("  {name} sits in zone {zone}");
    }
    for (index, (name, _)) in zones.iter().enumerate() {
        println!("  {index}: {name}");
    }

    // while let keeps going as long as the pattern matches.
    let mut stack = vec![1, 2, 3];
    while let Some(top) = stack.pop() {
        print!("{top} ");
    }
    println!();

    // if let, with an else branch, and let-else for the early return.
    let event = Event::Reading { device: String::from("SNS-07"), celsius: 19.6 };
    if let Event::Reading { device, celsius } = &event {
        println!("{device} reported {celsius}C");
    } else {
        println!("not a reading");
    }

    let Event::Reading { celsius, .. } = &event else {
        panic!("expected a reading");
    };
    println!("let-else bound {celsius}");

    // Match: alternatives, ranges, guards, bindings, and nested patterns.
    for event in [
        Event::Reading { device: String::from("SNS-01"), celsius: -18.4 },
        Event::Reading { device: String::from("SNS-04"), celsius: 31.2 },
        Event::Offline(String::from("SNS-09")),
        Event::Heartbeat,
    ] {
        let message = match event {
            Event::Reading { ref device, celsius } if celsius > 30.0 => {
                format!("{device} is too warm")
            }
            Event::Reading { ref device, celsius: c @ ..=0.0 } => {
                format!("{device} is below freezing at {c}")
            }
            Event::Reading { device, .. } => format!("{device} is nominal"),
            Event::Offline(device) => format!("{device} is offline"),
            Event::Heartbeat => String::from("heartbeat"),
        };
        println!("{message}");
    }

    for zone in [1u8, 3, 5, 9] {
        let band = match zone {
            1 | 2 => "central",
            3..=4 => "suburban",
            5..=6 => "outer",
            _ => "off the network",
        };
        println!("zone {zone} is {band}");
    }

    // Nested patterns reach into a structure in one step.
    let readings = vec![
        Some(Reading { device: String::from("SNS-01"), celsius: 21.4, battery: 88 }),
        None,
    ];
    for entry in &readings {
        match entry {
            Some(Reading { device, battery: 80..=100, .. }) => println!("{device} is well charged"),
            Some(Reading { device, .. }) => println!("{device} needs a charge"),
            None => println!("no reading"),
        }
    }
}
