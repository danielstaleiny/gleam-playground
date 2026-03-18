import compiled/loom/feed_grid
import compiled/loom/feed_page
import compiled/loom/index
import compiled/loom/upload_page
import ds
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http.{Get, Post}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import media_feed
import models/media.{type MediaItem}
import pubsub
import supabase
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ps: Subject(pubsub.Message)) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  let assert Ok(priv) = wisp.priv_directory("main")
  use <- wisp.serve_static(req, under: "static", from: priv <> "/static")

  case wisp.path_segments(req) {
    [] -> index_page(req)
    ["add"] -> add_person(req, ps)
    ["feed"] -> feed_page(req)
    ["feed", "search"] -> feed_search(req, ps)
    ["upload"] -> upload(req)
    _ -> wisp.not_found()
  }
}

fn index_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.html_response(index.render(title: "Datastar + Gleam SSE"), 200)
}

fn add_person(req: Request, ps: Subject(pubsub.Message)) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_string_body(req)

  let #(name, email) = parse_name_email(body)

  case name, email {
    "", _ | _, "" -> wisp.bad_request("missing name or email")
    _, _ -> {
      process.send(ps, pubsub.Publish(pubsub.AddPerson(name, email)))

      let event =
        ds.patch_signals(json.object([
          #("name", json.string("")),
          #("email", json.string("")),
        ]))
      wisp.ok()
      |> wisp.set_header("content-type", "text/event-stream")
      |> wisp.set_header("cache-control", "no-cache")
      |> wisp.string_body(ds.event_to_string(event))
    }
  }
}

fn feed_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.html_response(feed_page.render(title: "Content Feed"), 200)
}

fn feed_search(req: Request, _ps: Subject(pubsub.Message)) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_string_body(req)

  let #(search_query, search_type) = parse_search_params(body)

  let items = load_feed_items()
  let filtered = case search_query {
    "" -> items
    q ->
      case search_type {
        "place" -> media_feed.search_by_place(items, q)
        _ -> media_feed.search_by_user(items, q)
      }
  }

  let html = feed_grid.render(items: filtered) |> string.trim
  let event = ds.patch_elements("#feed-grid", ds.Inner, html)

  wisp.ok()
  |> wisp.set_header("content-type", "text/event-stream")
  |> wisp.set_header("cache-control", "no-cache")
  |> wisp.string_body(ds.event_to_string(event))
}

fn parse_search_params(body: String) -> #(String, String) {
  let decoder = {
    use query <- decode.field("search_query", decode.string)
    use stype <- decode.field("search_type", decode.string)
    decode.success(#(query, stype))
  }
  case json.parse(body, decoder) {
    Ok(pair) -> pair
    Error(_) -> {
      let params = uri.parse_query(body) |> result.unwrap([])
      #(
        list.key_find(params, "search_query") |> result.unwrap(""),
        list.key_find(params, "search_type") |> result.unwrap("user"),
      )
    }
  }
}

fn upload(req: Request) -> Response {
  case req.method {
    Get -> upload_page(req)
    Post -> handle_upload(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn upload_page(_req: Request) -> Response {
  wisp.html_response(upload_page.render(title: "Upload Photos"), 200)
}

fn handle_upload(req: Request) -> Response {
  use formdata <- wisp.require_form(req)

  case supabase.get_config() {
    Error(_) -> {
      wisp.internal_server_error()
      |> wisp.string_body("Supabase not configured")
    }
    Ok(config) -> {
      let people =
        list.key_find(formdata.values, "people") |> result.unwrap("")
      let place =
        list.key_find(formdata.values, "place") |> result.unwrap("")

      list.each(formdata.files, fn(file_pair) {
        let #(_field, uploaded_file) = file_pair
        let storage_path =
          wisp.random_string(16)
          <> file_extension(uploaded_file.file_name)
        let content_type =
          supabase.guess_content_type(uploaded_file.file_name)

        let _ =
          supabase.upload_from_path(
            config,
            uploaded_file.path,
            storage_path,
            content_type,
          )
        let _ =
          supabase.insert_photo(config, storage_path, people, place, "")
        Nil
      })

      wisp.redirect("/feed")
    }
  }
}

fn file_extension(filename: String) -> String {
  case string.split(filename, ".") |> list.last {
    Ok(ext) -> "." <> string.lowercase(ext)
    Error(_) -> ".jpg"
  }
}

/// Try loading photos from Supabase; fall back to placeholders.
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

fn parse_name_email(body: String) -> #(String, String) {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(#(name, email))
  }
  case json.parse(body, decoder) {
    Ok(pair) -> pair
    Error(_) -> {
      let params = uri.parse_query(body) |> result.unwrap([])
      #(
        list.key_find(params, "name") |> result.unwrap(""),
        list.key_find(params, "email") |> result.unwrap(""),
      )
    }
  }
}
