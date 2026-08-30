// Structs, impl blocks, associated functions, and the derive macros that
// write the boilerplate.

#[derive(Debug, Clone, PartialEq)]
struct Station {
    name: String,
    line: String,
    zone: u8,
    platforms: u8,
    step_free: bool,
}

// A tuple struct: fields by position rather than by name.
#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
struct GridPoint(i32, i32);

// A unit struct carries no data, only a type.
struct Metric;

impl Station {
    // An associated function: no `self`, called as Station::new.
    fn new(name: &str, line: &str, zone: u8) -> Self {
        Self {
            name: name.to_string(),
            line: line.to_string(),
            zone,
            platforms: 2,
            step_free: false,
        }
    }

    // A builder-style method that consumes and returns self.
    fn with_platforms(mut self, platforms: u8) -> Self {
        self.platforms = platforms;
        self
    }

    fn step_free(mut self) -> Self {
        self.step_free = true;
        self
    }

    // &self borrows, so the caller keeps the struct.
    fn label(&self) -> String {
        format!("{} (zone {})", self.name, self.zone)
    }

    // &mut self borrows exclusively and can change the fields.
    fn move_to_zone(&mut self, zone: u8) {
        self.zone = zone;
    }

    fn is_interchange(&self) -> bool {
        self.platforms > 3
    }
}

impl Default for Station {
    fn default() -> Self {
        Station::new("Unnamed", "Amber", 1)
    }
}

impl GridPoint {
    const ORIGIN: GridPoint = GridPoint(0, 0);

    fn distance_from_origin(&self) -> f64 {
        (((self.0 - Self::ORIGIN.0).pow(2) + (self.1 - Self::ORIGIN.1).pow(2)) as f64).sqrt()
    }
}

impl Metric {
    fn describe() -> &'static str {
        "a unit struct has no fields, only a type"
    }
}

fn main() {
    let mut alder = Station::new("Alder Cross", "Amber", 2)
        .with_platforms(2)
        .step_free();

    println!("{}", alder.label());
    println!("{alder:?}");
    println!("interchange: {}", alder.is_interchange());

    alder.move_to_zone(3);
    println!("moved: {}", alder.label());

    let copy = alder.clone();
    println!("equal after a clone: {}", copy == alder);

    println!("default: {}", Station::default().label());

    let point = GridPoint(45, -10);
    println!("{point:?} is {:.2} from {:?}", point.distance_from_origin(), GridPoint::ORIGIN);
    println!("Copy means this still works: {:?}", point);

    // Struct update syntax fills the rest from another value.
    let sibling = Station {
        name: String::from("Vellin Halt"),
        ..alder.clone()
    };
    println!("{}", sibling.label());

    println!("{}", Metric::describe());
}
