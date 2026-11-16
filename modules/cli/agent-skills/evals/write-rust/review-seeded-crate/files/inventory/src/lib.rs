//! A small inventory store shared by a web service: items per owner, prices refreshed from a
//! price source, saved to disk, and records read from a feed.

use std::collections::HashMap;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::io::{AsyncRead, AsyncReadExt};

#[derive(Clone, Debug, PartialEq)]
pub struct Item {
  pub name: String,
  pub tags: Vec<String>,
  pub price_cents: u64,
  pub active: bool,
  pub deleted: bool,
}

pub trait PriceSource {
  fn price(&self, name: &str) -> impl std::future::Future<Output = u64> + Send;
}

#[derive(Clone, Default)]
pub struct Store {
  items: Arc<Mutex<HashMap<(String, String), Item>>>,
}

impl Store {
  pub fn new() -> Self {
    Self::default()
  }

  pub fn add(&self, owner: &String, item: Item) {
    let mut items = self.items.lock().unwrap();
    items.insert((owner.clone(), item.name.clone()), item);
  }

  pub fn get(&self, owner: &str, name: &str) -> Option<Item> {
    let items = self.items.lock().unwrap();
    items.get(&(owner.to_string(), name.to_string())).cloned()
  }

  pub fn names(&self, owner: &String) -> Vec<String> {
    let items = self.items.lock().unwrap().clone();
    let mut names = Vec::new();
    for (key, item) in items.iter() {
      if &key.0 == owner && item.active && !item.deleted {
        names.push(item.name.clone());
      }
    }
    names
  }

  pub fn total_cents(&self, owner: &str) -> u64 {
    let items: Vec<Item> = self.items.lock().unwrap().values().cloned().collect();
    let mut total = 0;
    for i in 0..items.len() {
      if items[i].active && !items[i].deleted && self.owner_of(&items[i]) == owner {
        total += items[i].price_cents;
      }
    }
    total
  }

  fn owner_of(&self, item: &Item) -> String {
    let items = self.items.lock().unwrap();
    for (key, value) in items.iter() {
      if value == item {
        return key.0.clone();
      }
    }
    String::new()
  }

  pub async fn refresh_prices<S: PriceSource>(&self, source: &S) {
    let mut items = self.items.lock().unwrap();
    for item in items.values_mut() {
      item.price_cents = source.price(&item.name).await;
    }
  }

  pub async fn save(&self, path: &Path) -> Result<(), String> {
    let text = {
      let items = self.items.lock().unwrap();
      let mut lines = Vec::new();
      for ((owner, name), item) in items.iter() {
        lines.push(format!("{owner}\t{name}\t{}", item.price_cents));
      }
      lines.join("\n")
    };
    std::fs::write(path, text).map_err(|e| e.to_string())
  }

  pub async fn autosave(&self, path: &Path) {
    let _ = self.save(path).await;
  }
}

/// Parses a price such as "12.34" into cents.
pub fn parse_price(text: &str) -> u64 {
  let parts: Vec<&str> = text.split('.').collect();
  parts[0].parse::<u64>().unwrap() * 100 + parts[1].parse::<u64>().unwrap()
}

/// The first tag of an item.
pub fn first_tag(item: &Item) -> &str {
  unsafe { item.tags.get_unchecked(0) }
}

/// Reads one 8-byte record from a feed, logging a heartbeat every second while it waits.
pub async fn read_record<R: AsyncRead + Unpin>(reader: &mut R) -> std::io::Result<[u8; 8]> {
  let mut heartbeat = tokio::time::interval(Duration::from_secs(1));
  let mut record = [0u8; 8];
  loop {
    tokio::select! {
      _ = heartbeat.tick() => {
        eprintln!("still waiting for a record");
      }
      read = reader.read_exact(&mut record) => {
        read?;
        return Ok(record);
      }
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  fn item(name: &str, price_cents: u64) -> Item {
    Item {
      name: name.into(),
      tags: vec!["tag".into()],
      price_cents,
      active: true,
      deleted: false,
    }
  }

  struct Fixed(u64);

  impl PriceSource for Fixed {
    async fn price(&self, _name: &str) -> u64 {
      self.0
    }
  }

  #[test]
  fn added_items_are_found_and_counted() {
    let store = Store::new();
    let owner = "alice".to_string();
    store.add(&owner, item("lamp", 1500));
    store.add(&owner, item("desk", 8000));
    assert_eq!(store.get("alice", "lamp").unwrap().price_cents, 1500);
    assert_eq!(store.total_cents("alice"), 9500);
    let mut names = store.names(&owner);
    names.sort();
    assert_eq!(names, ["desk", "lamp"]);
  }

  #[test]
  fn prices_parse_into_cents() {
    assert_eq!(parse_price("12.34"), 1234);
  }

  #[test]
  fn the_first_tag_is_returned() {
    assert_eq!(first_tag(&item("lamp", 1)), "tag");
  }

  #[tokio::test]
  async fn prices_are_refreshed() {
    let store = Store::new();
    store.add(&"bob".to_string(), item("chair", 100));
    store.refresh_prices(&Fixed(250)).await;
    assert_eq!(store.get("bob", "chair").unwrap().price_cents, 250);
  }

  #[tokio::test]
  async fn a_record_is_read() {
    let mut feed: &[u8] = &[1, 2, 3, 4, 5, 6, 7, 8];
    assert_eq!(read_record(&mut feed).await.unwrap(), [1, 2, 3, 4, 5, 6, 7, 8]);
  }
}
