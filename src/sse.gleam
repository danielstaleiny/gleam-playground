import ds
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/json
import gleam/otp/actor
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
      let bridge = process.new_subject()
      process.send(ps, pubsub.Subscribe(bridge))

      let selector =
        process.new_selector()
        |> process.select(subject)
        |> process.select_map(bridge, PubSubEvent)

      process.send(subject, Init)

      Ok(actor.initialised(Nil) |> actor.selecting(selector))
    },
    loop: fn(_state: Nil, message: SseMessage, conn: mist.SSEConnection) {
      case message {
        Init -> {
          let _ =
            ds.send(
              conn,
              ds.patch_signals(json.object([
                #("name", json.string("")),
                #("connected", json.bool(True)),
              ])),
            )
          actor.continue(Nil)
        }
        PubSubEvent(pubsub.AddPerson(name)) -> {
          let html = "<div class=\"person\"><p>" <> name <> "</p></div>"
          let _ =
            ds.send(conn, ds.patch_elements("#people", ds.Append, html))
          actor.continue(Nil)
        }
      }
    },
  )
}
