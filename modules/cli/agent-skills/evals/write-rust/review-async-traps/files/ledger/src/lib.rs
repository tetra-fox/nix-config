//! A small accounts service: a read-through cache, a ledger that applies transfers while
//! reporting progress, and an event log written in the background.

use std::collections::HashMap;
use std::future::Future;
use std::sync::Mutex;
use std::time::Duration;

use tokio::sync::{Mutex as AsyncMutex, mpsc};

/// Values loaded on first use and kept.
#[derive(Default)]
pub struct Cache {
  entries: Mutex<HashMap<String, String>>,
  loads: Mutex<u64>,
}

impl Cache {
  /// Returns the value for `key`, calling `load` the first time.
  pub async fn get_or_load<F, Fut>(&self, key: &str, load: F) -> String
  where
    F: FnOnce() -> Fut,
    Fut: Future<Output = String>,
  {
    let entries = self.entries.lock().unwrap();
    if let Some(value) = entries.get(key) {
      return value.clone();
    }
    // release the lock before awaiting, so the future stays Send
    drop(entries);
    let value = load().await;
    self.entries.lock().unwrap().insert(key.to_owned(), value.clone());
    *self.loads.lock().unwrap() += 1;
    value
  }

  /// How many times a value had to be loaded.
  pub fn loads(&self) -> u64 {
    *self.loads.lock().unwrap()
  }
}

/// An account balance that changes by transfers.
#[derive(Default)]
pub struct Ledger {
  balance: AsyncMutex<i64>,
}

impl Ledger {
  /// Applies `delta`; the write to the store takes a moment.
  pub async fn apply(&self, delta: i64) {
    let mut balance = self.balance.lock().await;
    tokio::time::sleep(Duration::from_millis(50)).await;
    *balance += delta;
  }

  pub async fn balance(&self) -> i64 {
    *self.balance.lock().await
  }

  /// Applies `delta`, reporting the balance every `every` until the transfer is done.
  pub async fn apply_with_progress(&self, delta: i64, every: Duration, report: impl Fn(i64)) {
    let apply = self.apply(delta);
    tokio::pin!(apply);
    let mut ticks = tokio::time::interval(every);
    // the first tick completes at once
    ticks.tick().await;
    loop {
      tokio::select! {
        () = &mut apply => return,
        _ = ticks.tick() => {
          let balance = self.balance.lock().await;
          report(*balance);
        }
      }
    }
  }
}

/// Lines written to the event log by a background task.
pub struct EventLog {
  lines: mpsc::UnboundedSender<String>,
}

impl EventLog {
  /// Starts the background writer, which hands each line to `write`.
  pub fn start(write: impl Fn(&str) + Send + 'static) -> Self {
    let (lines, mut incoming) = mpsc::unbounded_channel::<String>();
    tokio::spawn(async move {
      while let Some(line) = incoming.recv().await {
        assert!(!line.contains('\n'), "a log line holds one line");
        write(&line);
      }
    });
    Self { lines }
  }

  /// Queues `line` for the log.
  pub fn log(&self, line: impl Into<String>) {
    let _ = self.lines.send(line.into());
  }
}

#[cfg(test)]
mod tests {
  use std::sync::Arc;

  use super::*;

  #[tokio::test]
  async fn a_value_is_loaded_once() {
    let cache = Cache::default();
    let first = cache.get_or_load("a", || async { "1".to_string() }).await;
    let second = cache.get_or_load("a", || async { "2".to_string() }).await;
    assert_eq!((first.as_str(), second.as_str(), cache.loads()), ("1", "1", 1));
  }

  #[tokio::test]
  async fn a_transfer_is_applied_and_progress_reported_at_the_end() {
    let ledger = Ledger::default();
    let reports = Arc::new(Mutex::new(Vec::new()));
    let seen = reports.clone();
    ledger
      .apply_with_progress(5, Duration::from_secs(1), move |balance| {
        seen.lock().unwrap().push(balance)
      })
      .await;
    assert_eq!(ledger.balance().await, 5);
  }

  #[tokio::test]
  async fn logged_lines_reach_the_writer() {
    let written = Arc::new(Mutex::new(Vec::new()));
    let sink = written.clone();
    let log = EventLog::start(move |line| sink.lock().unwrap().push(line.to_owned()));
    log.log("started");
    log.log("stopped");
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(*written.lock().unwrap(), ["started", "stopped"]);
  }
}
