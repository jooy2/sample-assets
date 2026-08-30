// Rust keeps tests beside the code they test. Run them with
// `rustc --test unit_tests.rs && ./unit_tests`, or `cargo test` in a project.

pub fn fizzbuzz(n: u32) -> String {
    match (n % 3, n % 5) {
        (0, 0) => String::from("FizzBuzz"),
        (0, _) => String::from("Fizz"),
        (_, 0) => String::from("Buzz"),
        _ => n.to_string(),
    }
}

#[derive(Debug, Default, PartialEq)]
pub struct Basket {
    items: Vec<(String, u64)>,
}

impl Basket {
    pub fn add(&mut self, sku: &str, cents: u64, quantity: u64) -> Result<&mut Self, String> {
        if quantity == 0 {
            return Err(String::from("quantity must be at least 1"));
        }
        self.items.push((sku.to_string(), cents * quantity));
        Ok(self)
    }

    pub fn total(&self) -> u64 {
        self.items.iter().map(|(_, cents)| cents).sum()
    }
}

fn main() {
    println!("{}", fizzbuzz(15));

    let mut basket = Basket::default();
    basket.add("KIT-0001", 1250, 1).unwrap();
    println!("total {}", basket.total());
}

// The test module is compiled only for `cargo test`, so it costs nothing in
// a release build.
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_numbers_are_returned_as_they_are() {
        assert_eq!(fizzbuzz(1), "1");
        assert_eq!(fizzbuzz(22), "22");
    }

    #[test]
    fn a_table_of_cases() {
        let cases = [(9, "Fizz"), (20, "Buzz"), (45, "FizzBuzz"), (0, "FizzBuzz")];

        for (input, expected) in cases {
            assert_eq!(fizzbuzz(input), expected, "fizzbuzz({input})");
        }
    }

    #[test]
    fn the_total_adds_up() {
        let mut basket = Basket::default();
        basket.add("KIT-0001", 1250, 1).unwrap();
        basket.add("OUT-0002", 3200, 2).unwrap();

        assert_eq!(basket.total(), 1250 + 6400);
    }

    #[test]
    fn a_zero_quantity_is_rejected() {
        let mut basket = Basket::default();
        let outcome = basket.add("KIT-0001", 100, 0);

        assert!(outcome.is_err());
        assert!(outcome.unwrap_err().contains("at least 1"));
    }

    #[test]
    #[should_panic(expected = "no basket")]
    fn a_panic_can_be_the_expected_result() {
        let missing: Option<Basket> = None;
        missing.expect("no basket");
    }

    #[test]
    #[ignore = "slow: run it with `cargo test -- --ignored`"]
    fn a_long_running_check() {
        assert_eq!((1..=1_000_000u64).sum::<u64>(), 500_000_500_000);
    }

    // A test can return Result, so `?` works inside it.
    #[test]
    fn returning_a_result() -> Result<(), String> {
        let mut basket = Basket::default();
        basket.add("STA-0007", 900, 3)?;
        assert_eq!(basket.total(), 2700);
        Ok(())
    }
}
