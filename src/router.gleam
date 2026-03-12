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
  // Log requests
  use <- wisp.log_request(req)
  // Crash protection
  use <- wisp.rescue_crashes

  // Serve static files from priv/static
  let assert Ok(priv) = wisp.priv_directory("main")
  use <- wisp.serve_static(req, under: "static", from: priv <> "/static")

  case wisp.path_segments(req) {
    [] -> index(req)
    ["add"] -> add_person(req, ps)
    _ -> wisp.not_found()
  }
}

fn index(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.html_response(index_html, 200)
}

fn add_person(req: Request, ps: Subject(pubsub.Message)) -> Response {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_string_body(req)

  let name_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(name)
  }
  let name = case json.parse(body, name_decoder) {
    Ok(name) -> name
    Error(_) ->
      uri.parse_query(body)
      |> result.unwrap([])
      |> list.key_find("name")
      |> result.unwrap("")
  }

  case name {
    "" -> wisp.bad_request("missing name")
    _ -> {
      process.send(ps, pubsub.Publish(pubsub.AddPerson(name)))

      // Return SSE that clears the input
      let sse_body =
        "event: datastar-patch-signals\ndata: signals {\"name\":\"\"}\n\n"
      wisp.ok()
      |> wisp.set_header("content-type", "text/event-stream")
      |> wisp.set_header("cache-control", "no-cache")
      |> wisp.string_body(sse_body)
    }
  }
}

const index_html = "<!DOCTYPE html>
<html>
<head>
  <title>Datastar + Gleam SSE</title>
  <script type=\"module\" src=\"/static/datastar.min.js\"></script>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 2rem auto; padding: 0 1rem; }
    .person { padding: 0.5rem; margin: 0.25rem 0; background: #f0f0f0; border-radius: 4px; }
    #status { color: green; font-weight: bold; }
    input { padding: 0.5rem; margin-right: 0.5rem; }
    button { padding: 0.5rem 1rem; cursor: pointer; }
  </style>
</head>
<body>
  <h1>Datastar + Gleam SSE</h1>

  <div data-signals=\"{name: '', connected: false}\" data-init=\"@get('/sse')\">
    <div>
      <span id=\"status\" data-text=\"$connected ? 'Connected' : 'Connecting...'\"></span>
    </div>

    <div>
      <input type=\"text\" data-bind:name placeholder=\"Enter name\" />
      <button data-on:click=\"@post('/add')\">Add Person</button>
    </div>

    <h2>People:</h2>
    <div id=\"people\"></div>
  </div>
</body>
</html>"
