// Threads, channels, and the Arc<Mutex<T>> pair that shares state safely.

use std::sync::mpsc;
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::Duration;

fn count_primes(limit: usize) -> usize {
    let mut composite = vec![false; limit + 1];
    let mut found = 0;

    for candidate in 2..=limit {
        if composite[candidate] {
            continue;
        }
        found += 1;
        let mut multiple = candidate * candidate;
        while multiple <= limit {
            composite[multiple] = true;
            multiple += candidate;
        }
    }
    found
}

fn main() {
    // A thread returns its value through the JoinHandle.
    let handles: Vec<_> = [50_000usize, 120_000, 30_000, 200_000]
        .into_iter()
        .map(|limit| thread::spawn(move || (limit, count_primes(limit))))
        .collect();

    for handle in handles {
        let (limit, primes) = handle.join().expect("the worker panicked");
        println!("{limit:>7} has {primes:>5} primes");
    }

    // A channel moves values from many senders to one receiver.
    let (sender, receiver) = mpsc::channel::<String>();

    for worker in 1..=3 {
        let sender = sender.clone();
        thread::spawn(move || {
            thread::sleep(Duration::from_millis(worker * 20));
            sender.send(format!("worker {worker} finished")).unwrap();
        });
    }
    drop(sender); // the last sender must go, or the loop never ends

    for message in receiver {
        println!("{message}");
    }

    // Arc shares ownership across threads; Mutex makes the value writable.
    let counter = Arc::new(Mutex::new(0u64));
    let mut handles = Vec::new();

    for _ in 0..4 {
        let counter = Arc::clone(&counter);
        handles.push(thread::spawn(move || {
            for _ in 0..25_000 {
                *counter.lock().unwrap() += 1;
            }
        }));
    }
    for handle in handles {
        handle.join().unwrap();
    }
    println!("counter reached {}", counter.lock().unwrap());

    // RwLock allows many readers or one writer.
    let table = Arc::new(RwLock::new(vec![String::from("Alder Cross")]));

    let readers: Vec<_> = (0..3)
        .map(|id| {
            let table = Arc::clone(&table);
            thread::spawn(move || format!("reader {id} sees {}", table.read().unwrap().len()))
        })
        .collect();
    for reader in readers {
        println!("{}", reader.join().unwrap());
    }

    table.write().unwrap().push(String::from("Quill Wharf"));
    println!("after the writer: {:?}", table.read().unwrap());

    // Scoped threads can borrow from the stack, with no Arc needed.
    let stations = vec!["Alder Cross", "Quill Wharf", "Saltwick Halt"];
    thread::scope(|scope| {
        for station in &stations {
            scope.spawn(move || println!("scoped thread sees {station}"));
        }
    });
    println!("the borrow ended with the scope: {} stations", stations.len());
}
