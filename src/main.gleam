import gleam/erlang/process
import gleam/http
import gleam/http/request
import mist
import pubsub
import sse
import router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(ps) = pubsub.start()
  let ps_subject = ps.data

  let wisp_handler =
    wisp_mist.handler(router.handle_request(_, ps_subject), secret_key_base)

  // Hybrid: SSE goes to Mist directly, everything else to Wisp
  let handler = fn(req: request.Request(mist.Connection)) {
    case req.method, request.path_segments(req) {
      http.Get, ["sse"] -> sse.handler(req, ps_subject)
      _, _ -> wisp_handler(req)
    }
  }

  let assert Ok(_) =
    handler
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
