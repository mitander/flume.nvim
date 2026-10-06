/// A reading keeps its value and validity together.
///
/// Documentation explains the boundary without becoming
/// a brighter block than the code it describes. The caller
/// decides whether an invalid reading should be retained.
#[derive(Debug)]
struct Reading {
    value: i64,
    valid: bool,
}

fn summarize(reading: &Reading) -> Option<i64> {
    // Ordinary comments provide supporting context.
    // Keep this dense block subordinate to identifiers,
    // while preserving enough contrast to read each line.
    // Fields, types, literals, and punctuation remain distinct.
    if reading.valid {
        Some(reading.value + 2)
    } else {
        None
    }
}
