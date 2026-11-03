use std::{fmt, io};

/// Rejection returns the offered input without exposing it in logs.
struct Rejected<T> {
    error: io::Error,
    owned: T,
}

impl<T> fmt::Debug for Rejected<T> {
    fn fmt(&self, output: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Log the error, never an owned file, buffer or payload.
        fmt::Debug::fmt(&self.error, output)
    }
}

fn submit<T>(input: T, ready: bool) -> Result<T, Rejected<T>> {
    if ready {
        return Ok(input);
    }
    Err(Rejected {
        error: io::Error::new(io::ErrorKind::WouldBlock, "worker is busy"),
        owned: input,
    })
}

fn main() {
    let payload = vec![40_u8, 2, 7];
    match submit(payload, false) {
        Ok(bytes) => println!("accepted {} bytes", bytes.len()),
        Err(rejected) => {
            eprintln!("{rejected:?}");
            let Rejected { error, owned } = rejected;
            assert_eq!(error.kind(), io::ErrorKind::WouldBlock);
            println!("retry keeps {} bytes: {owned:?}", owned.len());
        }
    }
}
