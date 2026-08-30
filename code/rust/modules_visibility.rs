// Modules, paths, and the visibility rules. Everything is private by
// default, including to a parent module.

mod network {
    // Public to anyone who can see `network`.
    pub const MAX_ZONE: u8 = 6;

    // Visible only inside `network` and its descendants.
    const OPERATOR: &str = "Veranix Transit";

    #[derive(Debug, Clone)]
    pub struct Station {
        pub name: String,
        pub zone: u8,
        // A private field: only this module can build or read it directly.
        serial: u32,
    }

    impl Station {
        pub fn new(name: &str, zone: u8) -> Result<Self, String> {
            if zone == 0 || zone > MAX_ZONE {
                return Err(format!("zone {zone} is outside 1-{MAX_ZONE}"));
            }
            Ok(Station {
                name: name.to_string(),
                zone,
                serial: next_serial(),
            })
        }

        pub fn serial(&self) -> u32 {
            self.serial
        }

        pub fn operator(&self) -> &'static str {
            OPERATOR
        }
    }

    // Private to the module: helpers that are not part of the interface.
    fn next_serial() -> u32 {
        use std::sync::atomic::{AtomicU32, Ordering};
        static COUNTER: AtomicU32 = AtomicU32::new(1);
        COUNTER.fetch_add(1, Ordering::Relaxed)
    }

    pub mod lines {
        // `super` reaches the parent module, `crate` the root.
        use super::Station;

        #[derive(Debug)]
        pub struct Line {
            pub name: String,
            stations: Vec<Station>,
        }

        impl Line {
            pub fn new(name: &str) -> Self {
                Line { name: name.to_string(), stations: Vec::new() }
            }

            pub fn add(&mut self, station: Station) -> &mut Self {
                self.stations.push(station);
                self
            }

            pub fn len(&self) -> usize {
                self.stations.len()
            }

            pub fn is_empty(&self) -> bool {
                self.stations.is_empty()
            }

            // pub(crate) is visible across this crate but not outside it.
            pub(crate) fn deepest_zone(&self) -> u8 {
                self.stations.iter().map(|s| s.zone).max().unwrap_or(0)
            }
        }
    }
}

// `use` brings a path into scope; `as` renames it.
use network::lines::{Line, Line as TransitLine};
use network::{Station, MAX_ZONE};

fn main() {
    let alder = Station::new("Alder Cross", 2).expect("a valid zone");
    let quill = Station::new("Quill Wharf", 3).expect("a valid zone");

    println!("{} serial {} run by {}", alder.name, alder.serial(), alder.operator());
    println!("the limit is zone {MAX_ZONE}");

    match Station::new("Far Halt", 9) {
        Ok(station) => println!("built {}", station.name),
        Err(error) => println!("rejected: {error}"),
    }

    let mut amber: Line = TransitLine::new("Amber");
    amber.add(alder.clone()).add(quill);

    println!("{} has {} stations, empty: {}", amber.name, amber.len(), amber.is_empty());
    println!("deepest zone on it: {}", amber.deepest_zone());

    // Fully qualified paths work without a `use`.
    let nether = network::Station::new("Nether Gate", 2).unwrap();
    println!("{} serial {}", nether.name, nether.serial());

    // alder.serial is private, so this is the only way in:
    //   println!("{}", alder.serial);   // error[E0616]: field is private
    println!("through the accessor: {}", alder.serial());
}
