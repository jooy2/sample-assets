// Traits define shared behaviour; generics use them as bounds. Static
// dispatch by default, dynamic dispatch behind `dyn`.

use std::fmt::{self, Display};

trait Shape {
    fn area(&self) -> f64;

    fn name(&self) -> String;

    // A default method: implementors may override it, but need not.
    fn describe(&self) -> String {
        format!("{} covering {:.2}", self.name(), self.area())
    }
}

struct Circle {
    radius: f64,
}

struct Rectangle {
    width: f64,
    height: f64,
}

impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }

    fn name(&self) -> String {
        String::from("circle")
    }
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }

    fn name(&self) -> String {
        String::from("rectangle")
    }

    fn describe(&self) -> String {
        format!("{}x{} rectangle", self.width, self.height)
    }
}

// Implementing a standard trait hooks a type into `{}` formatting.
impl Display for Circle {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "circle(r={})", self.radius)
    }
}

// A generic function with a trait bound: resolved at compile time.
fn largest_area<T: Shape>(shapes: &[T]) -> f64 {
    shapes.iter().map(|shape| shape.area()).fold(0.0, f64::max)
}

// The same bound in `where` form, with two parameters.
fn report<T, U>(left: &T, right: &U) -> String
where
    T: Shape,
    U: Shape,
{
    format!("{} vs {}", left.describe(), right.describe())
}

// dyn Trait is dynamic dispatch: the concrete type is decided at runtime.
fn total_area(shapes: &[Box<dyn Shape>]) -> f64 {
    shapes.iter().map(|shape| shape.area()).sum()
}

// A generic struct with its own impl block.
struct Pair<T> {
    left: T,
    right: T,
}

impl<T: PartialOrd + Copy> Pair<T> {
    fn larger(&self) -> T {
        if self.left > self.right {
            self.left
        } else {
            self.right
        }
    }
}

fn main() {
    let circles = [Circle { radius: 2.0 }, Circle { radius: 12.0 }];
    println!("largest circle: {:.2}", largest_area(&circles));

    let rectangle = Rectangle { width: 4.0, height: 4.0 };
    println!("{}", report(&circles[0], &rectangle));
    println!("Display: {}", circles[0]);

    // dyn Trait lets one collection hold several concrete types.
    let mixed: Vec<Box<dyn Shape>> = vec![
        Box::new(Circle { radius: 2.0 }),
        Box::new(Rectangle { width: 3.0, height: 6.0 }),
    ];
    for shape in &mixed {
        println!("  {}", shape.describe());
    }
    println!("total {:.2}", total_area(&mixed));

    println!("larger of 4 and 9: {}", Pair { left: 4, right: 9 }.larger());
    println!("larger of two floats: {}", Pair { left: 1.5, right: 0.5 }.larger());
}
