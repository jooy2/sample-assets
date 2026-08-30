// Enums carry data per variant, and `match` must handle every one of them.

#[derive(Debug, Clone, Copy, PartialEq)]
enum Priority {
    Low,
    Normal,
    High,
    Urgent,
}

#[derive(Debug)]
enum Shape {
    Circle { radius: f64 },
    Rectangle { width: f64, height: f64 },
    Triangle(f64, f64),
    Point,
}

#[derive(Debug)]
enum Command {
    Move { x: i32, y: i32 },
    Write(String),
    Colour(u8, u8, u8),
    Quit,
}

impl Priority {
    fn response_time(self) -> &'static str {
        match self {
            Priority::Low => "within a week",
            Priority::Normal => "within two days",
            Priority::High => "within four hours",
            Priority::Urgent => "immediately",
        }
    }
}

fn area(shape: &Shape) -> f64 {
    match shape {
        Shape::Circle { radius } => std::f64::consts::PI * radius * radius,
        Shape::Rectangle { width, height } => width * height,
        Shape::Triangle(base, height) => base * height / 2.0,
        Shape::Point => 0.0,
    }
}

fn describe(shape: &Shape) -> &'static str {
    match shape {
        // A guard adds a condition to a pattern.
        Shape::Rectangle { width, height } if width == height => "a square",
        Shape::Rectangle { .. } => "a rectangle",
        Shape::Circle { radius } if *radius > 10.0 => "a large circle",
        Shape::Circle { .. } => "a circle",
        _ => "something else",
    }
}

fn run(command: Command) -> String {
    match command {
        Command::Move { x, y } => format!("move to {x},{y}"),
        Command::Write(text) => format!("write {text:?}"),
        Command::Colour(r, g, b) => format!("colour #{r:02x}{g:02x}{b:02x}"),
        Command::Quit => String::from("quit"),
    }
}

fn main() {
    for priority in [Priority::Low, Priority::High, Priority::Urgent] {
        println!("{priority:?}: {}", priority.response_time());
    }

    let shapes = [
        Shape::Circle { radius: 2.0 },
        Shape::Rectangle { width: 4.0, height: 4.0 },
        Shape::Triangle(6.0, 2.5),
        Shape::Circle { radius: 12.0 },
        Shape::Point,
    ];

    for shape in &shapes {
        println!("{:<16} area {:7.2}", describe(shape), area(shape));
    }
    println!("total {:.2}", shapes.iter().map(area).sum::<f64>());

    for command in [
        Command::Move { x: 45, y: -10 },
        Command::Write(String::from("Alder Cross")),
        Command::Colour(200, 160, 42),
        Command::Quit,
    ] {
        println!("{}", run(command));
    }

    // if let and let else handle one variant without a full match.
    let shape = Shape::Circle { radius: 3.0 };
    if let Shape::Circle { radius } = shape {
        println!("radius {radius}");
    }

    let maybe = Some(Priority::High);
    let Some(priority) = maybe else {
        return;
    };
    println!("unwrapped with let-else: {priority:?}");

    // Ranges and bindings in patterns.
    for zone in [1u8, 3, 5, 9] {
        let band = match zone {
            1..=2 => "central",
            3..=4 => "suburban",
            n @ 5..=6 => {
                println!("  (matched and bound {n})");
                "outer"
            }
            _ => "off the network",
        };
        println!("zone {zone} is {band}");
    }
}
