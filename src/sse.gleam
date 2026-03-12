import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/otp/actor
import gleam/string_tree
import mist
import pubsub

type SseMessage {
  Init
  PubSubEvent(pubsub.Event)
}

pub fn handler(
  req: Request(mist.Connection),
  ps: Subject(pubsub.Message),
) -> response.Response(mist.ResponseData) {
  mist.server_sent_events(
    request: req,
    initial_response: response.new(200),
    init: fn(subject: Subject(SseMessage)) {
      // Create a bridge subject that wraps pubsub events into SseMessage
      let bridge = process.new_subject()
      process.send(ps, pubsub.Subscribe(bridge))

      let selector =
        process.new_selector()
        |> process.select(subject)
        |> process.select_map(bridge, PubSubEvent)

      // Send initial signals
      process.send(subject, Init)

      Ok(actor.initialised(Nil) |> actor.selecting(selector))
    },
    loop: fn(_state: Nil, message: SseMessage, conn: mist.SSEConnection) {
      case message {
        Init -> {
          let _ = send_signals(conn, "signals {\"name\":\"\",\"connected\":true}")
          actor.continue(Nil)
        }
        PubSubEvent(pubsub.AddPerson(name)) -> {
          let html = "<div class=\"person\"><p>" <> name <> "</p></div>"
          let _ =
            send_elements(
              conn,
              "selector #people\nmode append\nelements " <> html,
            )
          actor.continue(Nil)
        }
      }
    },
  )
}

fn send_signals(conn: mist.SSEConnection, data: String) {
  mist.send_event(
    conn,
    mist.event(string_tree.from_string(data))
      |> mist.event_name("datastar-patch-signals"),
  )
}

fn send_elements(conn: mist.SSEConnection, data: String) {
  mist.send_event(
    conn,
    mist.event(string_tree.from_string(data))
      |> mist.event_name("datastar-patch-elements"),
  )
}
