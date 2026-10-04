#[derive(Debug)]
struct Locked;
#[derive(Debug)]
struct Unlocked;

/// State is part of the type: a locked door has no `open` method.
#[derive(Debug)]
struct Door<State> {
    key: u32,
    _state: State,
}

impl Door<Locked> {
    fn unlock(self, key: u32) -> Result<Door<Unlocked>, Self> {
        if key != self.key {
            return Err(self); // Keep the door so the caller can retry.
        }
        Ok(Door {
            key,
            _state: Unlocked,
        })
    }
}

impl Door<Unlocked> {
    fn open(&self) -> &'static str {
        "Welcome in!"
    }
}

const KEY: u32 = 42;

fn main() {
    let door = Door {
        key: KEY,
        _state: Locked,
    };
    // door.open(); // This would fail to compile.
    let door = door.unlock(7).expect_err("wrong key");
    match door.unlock(KEY) {
        Ok(unlocked) => println!("{}", unlocked.open()),
        Err(locked) => eprintln!("Still locked: {locked:?}"),
    }
}
