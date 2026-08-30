// Box, Rc, and RefCell: heap allocation, shared ownership, and interior
// mutability.

use std::cell::RefCell;
use std::rc::{Rc, Weak};

// A recursive type needs indirection, or its size would be infinite.
#[derive(Debug)]
enum List {
    Cons(i32, Box<List>),
    Nil,
}

use List::{Cons, Nil};

#[derive(Debug)]
struct Node {
    name: String,
    children: RefCell<Vec<Rc<Node>>>,
    parent: RefCell<Weak<Node>>,
}

struct Guard(&'static str);

impl Drop for Guard {
    fn drop(&mut self) {
        println!("  dropping {}", self.0);
    }
}

fn main() {
    // Box: one owner, data on the heap.
    let list = Cons(1, Box::new(Cons(2, Box::new(Cons(3, Box::new(Nil))))));
    println!("{list:?}");

    let boxed: Box<dyn Fn(i32) -> i32> = Box::new(|n| n * 2);
    println!("boxed closure: {}", boxed(21));

    // Rc: several owners of the same immutable data, counted.
    let shared = Rc::new(String::from("Alder Cross"));
    println!("count after one: {}", Rc::strong_count(&shared));
    {
        let second = Rc::clone(&shared);
        let third = Rc::clone(&shared);
        println!("count inside the scope: {}", Rc::strong_count(&shared));
        println!("all three see {second} / {third}");
    }
    println!("count after the scope: {}", Rc::strong_count(&shared));

    // RefCell: mutation behind a shared reference, checked at runtime.
    let log = RefCell::new(Vec::<String>::new());
    log.borrow_mut().push(String::from("opened"));
    log.borrow_mut().push(String::from("closed"));
    println!("log: {:?}", log.borrow());

    // Two mutable borrows at once panic instead of failing to compile.
    let first = log.borrow_mut();
    println!("a second borrow_mut would panic: {}", log.try_borrow_mut().is_err());
    drop(first);

    // Rc<RefCell<T>> is the usual combination: shared and mutable.
    let counter = Rc::new(RefCell::new(0));
    let handles: Vec<Rc<RefCell<i32>>> = (0..3).map(|_| Rc::clone(&counter)).collect();
    for handle in &handles {
        *handle.borrow_mut() += 1;
    }
    println!("counter reached {}", counter.borrow());

    // Weak breaks a reference cycle: a child pointing back at its parent.
    let root = Rc::new(Node {
        name: String::from("Amber"),
        children: RefCell::new(vec![]),
        parent: RefCell::new(Weak::new()),
    });

    let leaf = Rc::new(Node {
        name: String::from("Alder Cross"),
        children: RefCell::new(vec![]),
        parent: RefCell::new(Rc::downgrade(&root)),
    });

    root.children.borrow_mut().push(Rc::clone(&leaf));

    println!(
        "leaf's parent: {:?}",
        leaf.parent.borrow().upgrade().map(|node| node.name.clone())
    );
    println!(
        "strong {}, weak {}",
        Rc::strong_count(&root),
        Rc::weak_count(&root)
    );

    // Drop runs at the end of the scope, in reverse order of creation.
    println!("scope with guards:");
    {
        let _a = Guard("first");
        let _b = Guard("second");
    }
    println!("done");
}
