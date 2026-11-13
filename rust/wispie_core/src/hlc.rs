use std::sync::atomic::{AtomicI64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

static LAST: AtomicI64 = AtomicI64::new(0);

pub fn observe(remote: i64) {
    LAST.fetch_max(remote, Ordering::Relaxed);
}

pub fn set(last: i64) {
    LAST.store(last, Ordering::Relaxed);
}

pub fn next(wall_millis: i64) -> i64 {
    let wall = wall_millis << 16;
    let mut last = LAST.load(Ordering::Relaxed);
    loop {
        if wall <= last {
            return LAST.fetch_add(1, Ordering::Relaxed).wrapping_add(1);
        }
        match LAST.compare_exchange_weak(last, wall, Ordering::Relaxed, Ordering::Relaxed) {
            Ok(_) => return wall,
            Err(actual) => last = actual,
        }
    }
}

pub fn now() -> i64 {
    let wall_millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;
    next(wall_millis)
}
