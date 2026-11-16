//! Chat rooms that fan each message out to every member, each member with its own bounded queue
//! so one slow reader holds up nobody else.

use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use tokio::sync::{RwLock, mpsc};
use tokio::task::JoinHandle;

/// How many messages a member may fall behind before it misses new ones.
const MEMBER_QUEUE: usize = 64;

/// A message as every member of its room receives it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Message {
  pub room: String,
  pub from: String,
  pub text: String,
}

/// Why a message was not sent.
#[derive(Debug, PartialEq, Eq)]
pub enum SendError {
  /// No room has this name.
  NoSuchRoom,
  /// The sender is not a member of the room.
  NotAMember,
}

impl fmt::Display for SendError {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    match self {
      Self::NoSuchRoom => f.write_str("no room has this name"),
      Self::NotAMember => f.write_str("the sender is not a member of the room"),
    }
  }
}

impl std::error::Error for SendError {}

/// The queues of a room's members, by username
type Members = HashMap<String, mpsc::Sender<Message>>;

/// The rooms of a server. Clones share the same rooms.
#[derive(Clone, Default)]
pub struct Rooms {
  inner: Arc<RwLock<HashMap<String, Members>>>,
}

impl Rooms {
  pub fn new() -> Self {
    Self::default()
  }

  /// Adds `user` to `room`, making the room if it is new, and returns the user's queue.
  ///
  /// Joining again replaces the user's previous queue, which then ends.
  pub async fn join(&self, room: impl Into<String>, user: impl Into<String>) -> mpsc::Receiver<Message> {
    let (sender, receiver) = mpsc::channel(MEMBER_QUEUE);
    let mut rooms = self.inner.write().await;
    rooms.entry(room.into()).or_default().insert(user.into(), sender);
    receiver
  }

  /// Sends `text` from `from` to every member of `room`, `from` included, and returns how many
  /// members it reached. A member whose queue is full misses the message.
  pub async fn send(&self, room: &str, from: &str, text: &str) -> Result<usize, SendError> {
    // the senders are cloned so the lock is released before anything is sent
    let members: Vec<mpsc::Sender<Message>> = {
      let rooms = self.inner.read().await;
      let members = rooms.get(room).ok_or(SendError::NoSuchRoom)?;
      if !members.contains_key(from) {
        return Err(SendError::NotAMember);
      }
      members.values().cloned().collect()
    };
    let message = Message {
      room: room.to_owned(),
      from: from.to_owned(),
      text: text.to_owned(),
    };
    let reached = members
      .iter()
      .filter(|member| member.try_send(message.clone()).is_ok())
      .count();
    Ok(reached)
  }

  /// Removes members whose queue was dropped, and rooms left empty.
  pub async fn prune(&self) {
    let mut rooms = self.inner.write().await;
    for members in rooms.values_mut() {
      members.retain(|_, sender| !sender.is_closed());
    }
    rooms.retain(|_, members| !members.is_empty());
  }

  /// Prunes the rooms every `every` until the returned task is aborted.
  pub fn prune_every(&self, every: Duration) -> JoinHandle<()> {
    let rooms = self.clone();
    tokio::spawn(async move {
      let mut ticks = tokio::time::interval(every);
      loop {
        ticks.tick().await;
        rooms.prune().await;
      }
    })
  }

  /// The names of the rooms, sorted.
  pub async fn names(&self) -> Vec<String> {
    let mut names: Vec<String> = self.inner.read().await.keys().cloned().collect();
    names.sort_unstable();
    names
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn a_message_reaches_every_member() {
    let rooms = Rooms::new();
    let mut alice = rooms.join("lobby", "alice").await;
    let mut bob = rooms.join("lobby", "bob").await;
    assert_eq!(rooms.send("lobby", "alice", "hi").await, Ok(2));
    assert_eq!(alice.recv().await.unwrap().text, "hi");
    assert_eq!(bob.recv().await.unwrap().from, "alice");
  }

  #[tokio::test]
  async fn only_members_send_to_rooms_that_exist() {
    let rooms = Rooms::new();
    let _alice = rooms.join("lobby", "alice").await;
    assert_eq!(rooms.send("attic", "alice", "hi").await, Err(SendError::NoSuchRoom));
    assert_eq!(rooms.send("lobby", "mallory", "hi").await, Err(SendError::NotAMember));
  }

  #[tokio::test]
  async fn members_who_left_are_pruned_with_their_empty_room() {
    let rooms = Rooms::new();
    drop(rooms.join("lobby", "alice").await);
    let _bob = rooms.join("den", "bob").await;
    rooms.prune().await;
    assert_eq!(rooms.names().await, ["den"]);
  }
}
