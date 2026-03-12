import compiled/loom/index
import ds
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http.{Get, Post}
import gleam/json
import gleam/list
import gleam/result
import gleam/uri
import pubsub
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ps: Subject(pubsub.Message)) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  let assert Ok(priv) = wisp.priv_directory("main")
  use <- wisp.serve_static(req, under: "static", from: priv <> "/static")

  case wisp.path_segments(req) {
    [] -> index_page(req)
    ["add"] -> add_person(req, ps)
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
