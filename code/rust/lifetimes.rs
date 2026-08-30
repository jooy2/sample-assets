// Lifetimes name how long a reference stays valid. The compiler infers most
// of them; these are the cases where it cannot.

// One input, one output: the lifetimes are elided and this needs no
// annotation. Written out, it would be `fn first<'a>(text: &'a str) -> &'a str`.
fn first_word(text: &str) -> &str {
    text.split_whitespace().next().unwrap_or("")
}

// Two inputs: the compiler cannot tell which one the result borrows from,
// so the annotation is required.
fn longest<'a>(left: &'a str, right: &'a str) -> &'a str {
    if left.len() >= right.len() {
        left
    } else {
        right
    }
}

// The result borrows only from `text`, so `separator` gets its own lifetime
// and may be dropped sooner.
fn before<'text>(text: &'text str, separator: &str) -> &'text str {
    match text.find(separator) {
        Some(at) => &text[..at],
        None => text,
    }
}

// A struct holding a reference must outlive it.
#[derive(Debug)]
struct Excerpt<'a> {
    source: &'a str,
    part: &'a str,
}

impl<'a> Excerpt<'a> {
    fn new(source: &'a str, needle: &str) -> Option<Self> {
        let at = source.find(needle)?;
        Some(Excerpt {
            source,
            part: &source[at..at + needle.len()],
        })
    }

    // &self and the returned reference share a lifetime by elision.
    fn context(&self) -> &str {
        self.source
    }
}

// 'static means the reference lives for the whole program: string literals
// and leaked allocations qualify.
fn banner() -> &'static str {
    "sample-assets"
}

fn main() {
    let line = String::from("Alder Cross,Amber,2");
    println!("first word: {}", first_word(&line));
    println!("before the comma: {}", before(&line, ","));

    let a = String::from("Saltwick Halt");
    let result;
    {
        let b = String::from("Quill Wharf");
        result = longest(a.as_str(), b.as_str()).to_string(); // copied out
        println!("longest inside the scope: {}", longest(&a, &b));
    }
    println!("kept as an owned String: {result}");

    let text = String::from("The tide came in and the tide went out");
    if let Some(excerpt) = Excerpt::new(&text, "tide") {
        println!("{excerpt:?}");
        println!("part {:?} of {} characters", excerpt.part, excerpt.context().len());
    }

    println!("static: {}", banner());

    // A reference cannot outlive what it points at; this is the error the
    // borrow checker exists to catch:
    //
    //   let dangling;
    //   {
    //       let temporary = String::from("gone at the brace");
    //       dangling = &temporary;
    //   }
    //   println!("{dangling}");   // error[E0597]: `temporary` does not live long enough

    // Owning the data instead is usually the fix.
    let owned = {
        let temporary = String::from("cloned out of the scope");
        temporary.clone()
    };
    println!("{owned}");
}
