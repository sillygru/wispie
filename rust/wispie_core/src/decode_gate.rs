use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::VecDeque;
use std::sync::Mutex;

#[derive(Default)]
pub struct DecodeGate {
    serial: u64,
    running: Option<u64>,
    high: VecDeque<u64>,
    normal: VecDeque<u64>,
}

impl DecodeGate {
    pub fn enqueue(&mut self, high: bool) -> u64 {
        self.serial += 1;
        let pending = if high {
            &mut self.high
        } else {
            &mut self.normal
        };
        pending.push_back(self.serial);
        self.serial
    }

    pub fn try_start(&mut self, ticket: u64) -> bool {
        if self.running.is_some() {
            return false;
        }
        let pending = if self.high.is_empty() {
            &mut self.normal
        } else {
            &mut self.high
        };
        if pending.front() != Some(&ticket) {
            return false;
        }
        pending.pop_front();
        self.running = Some(ticket);
        true
    }

    pub fn release(&mut self, ticket: u64) -> bool {
        if self.running != Some(ticket) {
            return false;
        }
        self.running = None;
        true
    }
}

static GATE: std::sync::LazyLock<Mutex<DecodeGate>> =
    std::sync::LazyLock::new(|| Mutex::new(DecodeGate::default()));

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Enqueue { high: bool },
    TryStart { ticket: u64 },
    Release { ticket: u64 },
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    let mut gate = GATE.lock().map_err(|error| error.to_string())?;
    match request {
        Request::Enqueue { high } => {
            let ticket = gate.enqueue(high);
            Ok(json!({"ticket": ticket, "started": gate.try_start(ticket)}))
        }
        Request::TryStart { ticket } => Ok(json!({"started": gate.try_start(ticket)})),
        Request::Release { ticket } if gate.release(ticket) => Ok(json!({})),
        Request::Release { .. } => Err("decode ticket does not own the gate".into()),
    }
}
