import compiled/loom/feed_grid
import ds
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/json
import gleam/otp/actor
import gleam/string
import media_feed
import mist
import pubsub

type FeedMessage {
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
    init: fn(subject: Subject(FeedMessage)) {
      let bridge = process.new_subject()
      process.send(ps, pubsub.Subscribe(bridge))

      let selector =
        process.new_selector()
        |> process.select(subject)
        |> process.select_map(bridge, PubSubEvent)

      process.send(subject, Init)

      Ok(actor.initialised(Nil) |> actor.selecting(selector))
    },
    loop: fn(_state: Nil, message: FeedMessage, conn: mist.SSEConnection) {
      case message {
        Init -> {
          let items = media_feed.generate_feed()
          let html = feed_grid.render(items:) |> string.trim

          let _ =
            ds.send(
              conn,
              ds.patch_signals(json.object([
                #("connected", json.bool(True)),
              ])),
            )
          let _ =
            ds.send(conn, ds.patch_elements("#feed-grid", ds.Inner, html))
          actor.continue(Nil)
        }
        PubSubEvent(_) -> actor.continue(Nil)
      }
    },
  )
}
