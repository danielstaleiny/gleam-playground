import datastar/ds_sse
import datastar/ds_wisp
import gleam/http.{Get}
import gleam/json
import html/span.{Person}
import web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> root(req)

    // This matches `/comments`.
    // ["comments"] -> comments(req)
    // // This matches `/comments/:id`.
    // // The `id` segment is bound to a variable and passed to the handler.
    // ["comments", id] -> show_comment(req, id)
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn root(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  // let obj = dict.new() |> dict.insert("name", "daniel") |> dict.to_list()
  // let obj = dict.from_list(["name", "Daniel"])
  // let obj = dict.new() |> dict.insert("name", "daniel") |> dict.to_list()
  // dict.from_list([#("key1", "value1")
  let obj = Person(name: "Daniel")

  wisp.log_info(span.render(span.person_encode(obj)))

  let json =
    json.object([
      #("name", json.string("Daniel")),
      #("surname", json.string("Surname")),
    ])
  let events = [
    // ds_sse.patch_signals()
    ds_sse.patch_signals(json)
    |> ds_sse.patch_signals_end,
    // ds_sse.patch_elements()
  // |> ds_sse.patch_elements_elements("<span>Hello</span>")
  // |> ds_sse.patch_elements_end,
  // ds_sse.patch_elements()
  //   |> ds_sse.patch_elements_elements(span.render(obj))
  //   |> ds_sse.patch_elements_end,
  ]

  wisp.ok()
  |> ds_wisp.send(events)
}
