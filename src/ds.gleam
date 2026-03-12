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
  case event {
    PatchSignalsEvent(signals, only_if_missing) -> {
      let lines = [
        "event: datastar-patch-signals",
        ..case only_if_missing {
          True -> ["data: onlyIfMissing true"]
          False -> []
        }
      ]
      list.append(lines, [
        "data: signals " <> json.to_string(signals),
        "",
        "",
      ])
      |> string.join("\n")
    }
    PatchElementsEvent(selector, merge_mode, elements, settle_duration, view_transition) -> {
      let lines = ["event: datastar-patch-elements"]
      let lines = case selector {
        Some(s) -> list.append(lines, ["data: selector " <> s])
        None -> lines
      }
      let lines = case merge_mode {
        Outer -> lines
        _ -> list.append(lines, ["data: mode " <> merge_mode_to_string(merge_mode)])
      }
      let lines = case settle_duration {
        300 -> lines
        n -> list.append(lines, ["data: settleDuration " <> int.to_string(n)])
      }
      let lines = case view_transition {
        True -> list.append(lines, ["data: useViewTransition true"])
        False -> lines
      }
      let lines = case elements {
        Some(html) -> list.append(lines, ["data: elements " <> html])
        None -> lines
      }
      list.append(lines, ["", ""])
      |> string.join("\n")
    }
  }
}

pub fn events_to_string(events: List(Event)) -> String {
  events
  |> list.map(event_to_string)
  |> string.join("\n")
}

// -- Send via Mist SSE connection --

pub fn send(conn: mist.SSEConnection, event: Event) {
  case event {
    PatchSignalsEvent(signals, only_if_missing) -> {
      let data = case only_if_missing {
        True -> "onlyIfMissing true\nsignals " <> json.to_string(signals)
        False -> "signals " <> json.to_string(signals)
      }
      mist.send_event(
        conn,
        mist.event(string_tree.from_string(data))
          |> mist.event_name("datastar-patch-signals"),
      )
    }
    PatchElementsEvent(selector, merge_mode, elements, settle_duration, view_transition) -> {
      let parts = []
      let parts = case selector {
        Some(s) -> list.append(parts, ["selector " <> s])
        None -> parts
      }
      let parts = case merge_mode {
        Outer -> parts
        _ -> list.append(parts, ["mode " <> merge_mode_to_string(merge_mode)])
      }
      let parts = case settle_duration {
        300 -> parts
        n -> list.append(parts, ["settleDuration " <> int.to_string(n)])
      }
      let parts = case view_transition {
        True -> list.append(parts, ["useViewTransition true"])
        False -> parts
      }
      let parts = case elements {
        Some(html) -> list.append(parts, ["elements " <> html])
        None -> parts
      }
      mist.send_event(
        conn,
        mist.event(string_tree.from_string(string.join(parts, "\n")))
          |> mist.event_name("datastar-patch-elements"),
      )
    }
  }
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
  Action(..action, headers: list.append(action.headers, [#(name, value)]))
}

/// Builds the action string for use in data-on:click, data-init, etc.
/// e.g. ds.get("/sse") |> ds.action  →  "@get('/sse')"
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

/// Set signals: ds.set_all("input", "'hello'")  →  "$input='hello'"
pub fn set_all(signals: String, expression: String) -> String {
  "$" <> signals <> "=" <> expression
}

/// Toggle signals: ds.toggle_all("visible")  →  "~visible"
pub fn toggle_all(signals: String) -> String {
  "~" <> signals
}

// -- Internal --

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
