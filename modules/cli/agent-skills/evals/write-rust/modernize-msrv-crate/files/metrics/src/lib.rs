//! Counters a service records, flushed to a sink in the background.

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;
use tokio::task::JoinHandle;

lazy_static! {
  /// Labels added to every line.
  static ref DEFAULT_LABELS: HashMap<&'static str, &'static str> = {
    let mut labels = HashMap::new();
    labels.insert("service", "api");
    labels
  };
}

static CONFIG: OnceCell<Config> = OnceCell::new();

#[derive(Clone, Debug, PartialEq)]
pub struct Config {
  pub prefix: String,
  pub flush_every: Duration,
}

/// Sets the process-wide configuration; returns false if it was already set.
pub fn init(config: Config) -> bool {
  CONFIG.set(config).is_ok()
}

pub fn config() -> Option<&'static Config> {
  CONFIG.get()
}

/// The part of `name` after the configured prefix, if it has the prefix and something after it.
pub fn label_for(name: &str) -> Option<String> {
  if let Some(config) = config() {
    if let Some(rest) = name.strip_prefix(config.prefix.as_str()) {
      if !rest.is_empty() {
        return Some(rest.to_string());
      }
    }
  }
  None
}

#[derive(Debug, PartialEq, Eq)]
pub enum SinkError {
  Closed,
}

impl fmt::Display for SinkError {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    f.write_str("the sink is closed")
  }
}

impl std::error::Error for SinkError {}

/// Where flushed lines go.
#[async_trait]
pub trait Sink {
  async fn write(&self, line: String) -> Result<(), SinkError>;
}

#[derive(Default)]
pub struct Recorder {
  counts: Mutex<HashMap<String, u64>>,
}

impl Recorder {
  pub fn incr(&self, name: &str) {
    let mut counts = self.counts.lock();
    *counts.entry(name.to_string()).or_insert(0) += 1;
  }

  pub fn get(&self, name: &str) -> u64 {
    self.counts.lock().get(name).copied().unwrap_or(0)
  }

  /// Writes one line per counter to `sink` and returns how many it wrote.
  pub async fn flush<S: Sink>(&self, sink: &S) -> Result<usize, SinkError> {
    let mut lines: Vec<String> = {
      let counts = self.counts.lock();
      counts
        .iter()
        .map(|(name, count)| {
          let labels: Vec<String> = DEFAULT_LABELS.iter().map(|(k, v)| format!("{k}={v}")).collect();
          format!("{name} {count} {}", labels.join(","))
        })
        .collect()
    };
    lines.sort();
    for line in &lines {
      sink.write(line.clone()).await?;
    }
    Ok(lines.len())
  }
}

#[allow(dead_code)]
fn legacy_format(name: &str, count: u64) -> String {
  format!("{name}:{count}")
}

/// Flushes `recorder` to `sink` every `every`, forever.
pub fn spawn_flusher<S>(recorder: Arc<Recorder>, sink: Arc<S>, every: Duration) -> JoinHandle<()>
where
  S: Sink + Send + Sync + 'static,
{
  tokio::spawn(async move {
    loop {
      tokio::time::sleep(every).await;
      let _ = recorder.flush(&*sink).await;
    }
  })
}

#[cfg(test)]
mod tests {
  use super::*;

  #[derive(Default)]
  struct Lines(Mutex<Vec<String>>);

  #[async_trait]
  impl Sink for Lines {
    async fn write(&self, line: String) -> Result<(), SinkError> {
      self.0.lock().push(line);
      Ok(())
    }
  }

  struct Closed;

  #[async_trait]
  impl Sink for Closed {
    async fn write(&self, _line: String) -> Result<(), SinkError> {
      Err(SinkError::Closed)
    }
  }

  #[tokio::test]
  async fn counters_are_flushed_with_the_default_labels() {
    let recorder = Recorder::default();
    recorder.incr("requests");
    recorder.incr("requests");
    recorder.incr("errors");
    let sink = Lines::default();
    assert_eq!(recorder.flush(&sink).await, Ok(2));
    assert_eq!(*sink.0.lock(), ["errors 1 service=api", "requests 2 service=api"]);
  }

  #[tokio::test]
  async fn a_closed_sink_fails_the_flush() {
    let recorder = Recorder::default();
    recorder.incr("requests");
    assert!(matches!(recorder.flush(&Closed).await, Err(SinkError::Closed)));
  }

  #[tokio::test(flavor = "multi_thread")]
  async fn the_flusher_runs_in_the_background() {
    let recorder = Arc::new(Recorder::default());
    recorder.incr("requests");
    let sink = Arc::new(Lines::default());
    let flusher = spawn_flusher(recorder, sink.clone(), Duration::from_millis(10));
    tokio::time::sleep(Duration::from_millis(50)).await;
    flusher.abort();
    assert!(!sink.0.lock().is_empty());
  }

  #[test]
  fn labels_are_the_name_after_the_prefix() {
    init(Config {
      prefix: "app.".into(),
      flush_every: Duration::from_secs(1),
    });
    assert_eq!(label_for("app.requests").as_deref(), Some("requests"));
    assert_eq!(label_for("app."), None);
    assert_eq!(label_for("other"), None);
  }
}
