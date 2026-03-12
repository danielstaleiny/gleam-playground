/// Local Datastar SSE helpers.
/// Builds SSE events for both HTTP responses and Mist SSE connections.

import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import mist

// -- Types --

pub type MergeMode {
  After
  Append
  Before
  Inner
  Outer
  Prepend
  Replace
  Remove
}

pub type Event {
  PatchSignalsEvent(signals: Json, only_if_missing: Bool)
  PatchElementsEvent(
    selector: Option(String),
    merge_mode: MergeMode,
    elements: Option(String),
    settle_duration: Int,
    view_transition: Bool,
  )
}

// -- Builders --

pub fn patch_signals(signals: Json) -> Event {
  PatchSignalsEvent(signals:, only_if_missing: False)
}

pub fn patch_signals_only_if_missing(event: Event, value: Bool) -> Event {
  case event {
    PatchSignalsEvent(..) -> PatchSignalsEvent(..event, only_if_missing: value)
    _ -> event
  }
}

pub fn patch_elements(selector: String, mode: MergeMode, html: String) -> Event {
  PatchElementsEvent(
    selector: Some(selector),
    merge_mode: mode,
    elements: Some(html),
    settle_duration: 300,
    view_transition: False,
  )
}

// -- Serialize to SSE string (for HTTP responses) --

pub fn event_to_string(event: Event) -> String {
  let data_lines =
    event_data_lines(event)
    |> list.map(fn(line) { "data: " <> line })
  ["event: " <> event_name(event), ..data_lines]
  |> list.append(["", ""])
  |> string.join("\n")
}

pub fn events_to_string(events: List(Event)) -> String {
  events
  |> list.map(event_to_string)
  |> string.join("\n")
}

// -- Send via Mist SSE connection --

pub fn send(conn: mist.SSEConnection, event: Event) {
  let data =
    event_data_lines(event)
    |> string.join("\n")
    |> string_tree.from_string
  mist.send_event(
    conn,
    mist.event(data) |> mist.event_name(event_name(event)),
  )
}

// -- Action builders (for HTML attributes in server-side templates) --

pub type Action {
  Action(method: String, url: String, headers: List(#(String, String)))
}

pub fn get(url: String) -> Action {
  Action(method: "get", url:, headers: [])
}

pub fn post(url: String) -> Action {
  Action(method: "post", url:, headers: [])
}

pub fn put(url: String) -> Action {
  Action(method: "put", url:, headers: [])
}

pub fn patch(url: String) -> Action {
  Action(method: "patch", url:, headers: [])
}

pub fn delete(url: String) -> Action {
  Action(method: "delete", url:, headers: [])
}

pub fn with_header(action: Action, name: String, value: String) -> Action {
  Action(..action, headers: [#(name, value), ..action.headers])
}

/// Builds the action string for data-on:click, data-init, etc.
/// e.g. ds.get("/sse") |> ds.action  ->  "@get('/sse')"
pub fn action(action: Action) -> String {
  let headers_str = case action.headers {
    [] -> ""
    hdrs ->
      hdrs
      |> list.map(fn(h) { "'" <> h.0 <> "': '" <> h.1 <> "'" })
      |> string.join(", ")
      |> fn(s) { ", {headers: {" <> s <> "}}" }
  }
  "@" <> action.method <> "('" <> action.url <> "'" <> headers_str <> ")"
}

/// Set signals: ds.set_all("input", "'hello'")  ->  "$input='hello'"
pub fn set_all(signals: String, expression: String) -> String {
  "$" <> signals <> "=" <> expression
}

/// Toggle signals: ds.toggle_all("visible")  ->  "~visible"
pub fn toggle_all(signals: String) -> String {
  "~" <> signals
}

// -- Internal --

fn event_name(event: Event) -> String {
  case event {
    PatchSignalsEvent(..) -> "datastar-patch-signals"
    PatchElementsEvent(..) -> "datastar-patch-elements"
  }
}

fn event_data_lines(event: Event) -> List(String) {
  case event {
    PatchSignalsEvent(signals, only_if_missing) ->
      [
        case only_if_missing {
          True -> Some("onlyIfMissing true")
          False -> None
        },
        Some("signals " <> json.to_string(signals)),
      ]
      |> option.values

    PatchElementsEvent(selector, merge_mode, elements, settle_duration, view_transition) ->
      [
        selector |> option.map(fn(s) { "selector " <> s }),
        case merge_mode {
          Outer -> None
          mode -> Some("mode " <> merge_mode_to_string(mode))
        },
        case settle_duration {
          300 -> None
          n -> Some("settleDuration " <> int.to_string(n))
        },
        case view_transition {
          True -> Some("useViewTransition true")
          False -> None
        },
      ]
      |> option.values
      |> list.append(element_lines(elements))
  }
}

fn element_lines(elements: Option(String)) -> List(String) {
  case elements {
    None -> []
    Some(html) ->
      html
      |> string.trim
      |> string.split("\n")
      |> list.map(fn(line) { "elements " <> line })
  }
}

fn merge_mode_to_string(mode: MergeMode) -> String {
  case mode {
    After -> "after"
    Append -> "append"
    Before -> "before"
    Inner -> "inner"
    Outer -> "outer"
    Prepend -> "prepend"
    Replace -> "replace"
    Remove -> "remove"
  }
}
