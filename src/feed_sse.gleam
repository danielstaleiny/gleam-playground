import compiled/loom/feed_grid
import ds
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/string
import media_feed
import mist
import models/media.{type MediaItem}
import pubsub
import supabase

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
          let items = load_feed_items()
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

/// Try to load photos from Supabase; fall back to placeholder feed.
fn load_feed_items() -> List(MediaItem) {
  case supabase.get_config() {
    Ok(config) ->
      case supabase.list_photos(config) {
        Ok(photos) ->
          case photos {
            [] -> media_feed.generate_feed()
            _ -> {
              let uploaded =
                list.map(photos, fn(p) {
                  media_feed.UploadedPhoto(
                    id: p.id,
                    url: supabase.public_url(config, p.storage_path),
                    people: p.people,
                    place: p.place,
                    date_taken: p.date_taken,
                  )
                })
              media_feed.uploaded_to_feed(uploaded)
            }
          }
        Error(_) -> media_feed.generate_feed()
      }
    Error(_) -> media_feed.generate_feed()
  }
}
