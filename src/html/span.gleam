import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom

pub type Person {
  Person(name: String)
}

pub fn person_encode(person: Person) -> Dynamic {
  dynamic.properties([
    #(atom.to_dynamic(atom.create("name")), dynamic.string(person.name)),
  ])
}

// pub type RenderResult {
//   Ok(String)
//   Error(String)
// }

@external(erlang, "Elixir.Html.Span", "render")
pub fn render(obj: Dynamic) -> String
// pub fn render(p: Person) -> String {
//   render_(p.name)
// }
