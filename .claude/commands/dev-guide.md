# Datastar + Gleam + Loom Development Guide

You are helping develop a server-side rendered web application using **Datastar** (client-side reactivity via SSE) + **Gleam** (BEAM language) + **Loom** templates (Glimr's template engine).

## Architecture

```
Browser (Datastar JS) <--SSE--> Mist (long-lived SSE) <--pubsub--> Wisp (HTTP routes)
```

- **Mist** handles SSE connections at `/sse` (long-lived, pushes events)
- **Wisp** handles normal HTTP routes (`GET /`, `POST /add`, etc.)
- **Hybrid routing** in `src/main.gleam`: Mist intercepts `/sse`, delegates rest to Wisp
- **Pubsub actor** (`src/pubsub.gleam`) broadcasts events to all SSE subscribers

## Key Files

| File | Purpose |
|------|---------|
| `src/main.gleam` | Entry point, hybrid Mist/Wisp routing |
| `src/router.gleam` | Wisp HTTP routes, uses Loom templates |
| `src/sse.gleam` | SSE handler, subscribes to pubsub, pushes HTML via Loom templates |
| `src/ds.gleam` | Local Datastar SSE protocol helpers (events, actions) |
| `src/pubsub.gleam` | Broadcast actor (Subscribe/Publish) |
| `src/models/person.gleam` | Data types |
| `src/resources/views/*.loom.html` | Loom templates (source of truth for HTML) |
| `src/compiled/loom/*.gleam` | Generated Gleam from Loom templates (committed to git) |
| `src/loom_compile.gleam` | Template compiler script |

## Loom Template Workflow

### 1. Write template
Create/edit `.loom.html` files in `src/resources/views/`:

```html
@import(models/person.{type Person})
@props(name: String, email: String)

<div class="person">
  <p>{{ name }}</p>
  <p>{{ email }}</p>
</div>
```

### 2. Compile templates
```bash
gleam run -m loom_compile
```
This generates typed `render()` functions in `src/compiled/loom/`.

### 3. Use in Gleam code
```gleam
import compiled/loom/person_card

let html = person_card.render(name: "Alice", email: "alice@example.com")
```

### Important: Compiled files must be in git
`src/compiled/` is NOT gitignored because `gleam build` needs them. The chicken-and-egg: `gleam run -m loom_compile` requires a successful build, but the build requires the compiled files to exist.

If compiled files are missing, create stubs with matching signatures, then run `gleam run -m loom_compile`.

## Datastar SSE Protocol

### Sending events via Mist SSE (long-lived connection)
```gleam
import ds

// Push signals to client
ds.send(conn, ds.patch_signals(json.object([
  #("name", json.string("Alice")),
])))

// Push HTML fragment to DOM
ds.send(conn, ds.patch_elements("#target", ds.Append, html))
```

### Sending events via HTTP response (one-shot)
```gleam
let event = ds.patch_signals(json.object([#("name", json.string(""))]))
wisp.ok()
|> wisp.set_header("content-type", "text/event-stream")
|> wisp.set_header("cache-control", "no-cache")
|> wisp.string_body(ds.event_to_string(event))
```

### Multiline HTML in SSE
Loom templates produce multiline HTML. The `ds` module handles this by repeating `data: elements` for each line:
```
data: selector #people
data: mode append
data: elements <div class="person">
data: elements   <p>Alice</p>
data: elements </div>
```
Always use `ds.send()` or `ds.event_to_string()` — never construct SSE strings manually.

## Datastar HTML Attributes

```html
<!-- Declare reactive signals -->
<div data-signals="{name: '', connected: false}">

<!-- SSE connection -->
<div data-init="@get('/sse')">

<!-- Two-way binding -->
<input data-bind:name />

<!-- Event handler -->
<button data-on:click="@post('/add')">

<!-- Reactive text -->
<span data-text="$connected ? 'Connected' : 'Connecting...'">
```

## ds.gleam API Reference

### Event Builders
- `ds.patch_signals(json)` — send signal updates
- `ds.patch_elements(selector, mode, html)` — send HTML to DOM
- `ds.MergeMode`: `Append | Prepend | Inner | Outer | After | Before | Replace | Remove`

### Action Builders (for server-side template attributes)
- `ds.get(url)`, `ds.post(url)`, `ds.put(url)`, `ds.patch(url)`, `ds.delete(url)`
- `ds.with_header(action, name, value)` — add header
- `ds.action(action)` — render to string like `@get('/sse')`
- `ds.set_all(signal, expr)` — renders `$signal=expr`
- `ds.toggle_all(signal)` — renders `~signal`

## Common Commands

```bash
gleam run -m loom_compile   # Compile .loom.html -> .gleam
gleam build                 # Build project
gleam run -m main           # Start server on port 8000
pkill -f beam.smp           # Kill server
```

## Adding a New Page/Component

1. Create `src/resources/views/my_thing.loom.html` with `@props(...)` and HTML
2. Run `gleam run -m loom_compile`
3. Import `compiled/loom/my_thing` in your Gleam code
4. Call `my_thing.render(...)` — it returns a `String`
5. For SSE fragments: wrap with `string.trim` before passing to `ds.send()` (Loom adds leading/trailing newlines)

## Adding a New SSE Event

1. Add variant to `pubsub.Event` in `src/pubsub.gleam`
2. Handle in `src/sse.gleam` loop — use `ds.send(conn, ...)` to push to client
3. Publish from route handler: `process.send(ps, pubsub.Publish(MyEvent(...)))`

## Tech Stack

- **Gleam 1.14+** (via nix-shell with nixos-unstable)
- **Datastar RC.8** (CDN: `https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.0-RC.8/bundles/datastar.js`)
- **Mist** — HTTP server with native SSE support
- **Wisp** — HTTP framework for routing/middleware
- **Glimr/Loom** — template engine (compile-time code generation)
