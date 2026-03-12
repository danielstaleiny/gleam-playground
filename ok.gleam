import gleam/io
import gleam/result.{try}
import wisp.{type Request, type Response}

pub fn main() {
  io.println("Hello from datastar_gleam_palyground!")
}

pub type Context {
  Context(secret: String)
}

pub fn handle_request(request: Request, context: Context) -> Response {
  wisp.ok()
}
