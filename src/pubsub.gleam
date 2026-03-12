import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type Message {
  Subscribe(Subject(Event))
  Publish(Event)
}

pub type Event {
  AddPerson(name: String)
}

pub fn start() {
  actor.new([])
  |> actor.on_message(fn(clients: List(Subject(Event)), message) {
    case message {
      Subscribe(client) -> actor.continue([client, ..clients])
      Publish(event) -> {
        list.each(clients, fn(c) { process.send(c, event) })
        actor.continue(clients)
      }
    }
  })
  |> actor.start
}
