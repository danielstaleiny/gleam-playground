import filepath
import gleam/dict
import gleam/io
import gleam/list
import gleam/string
import glimr/loom/generator
import glimr/loom/lexer
import glimr/loom/parser
import simplifile

const views_path = "src/resources/views/"

const output_path = "src/compiled/loom/"

pub fn main() {
  let assert Ok(files) = simplifile.get_files(views_path)

  files
  |> list.filter(fn(f) { string.ends_with(f, ".loom.html") })
  |> list.each(fn(path) {
    path
    |> string.replace(views_path, "")
    |> string.replace(".loom.html", "")
    |> fn(name) { compile(path, "compiled/loom/" <> name) }
  })
}

fn compile(path: String, module_name: String) {
  let assert Ok(content) = simplifile.read(path)
  let assert Ok(tokens) = lexer.tokenize(content)
  let assert Ok(template) = parser.parse(tokens)
  let assert Ok(_) = generator.validate_template(template, path)

  let generated =
    generator.generate(template, module_name, False, dict.new(), dict.new())

  let out_file =
    output_path <> string.replace(module_name, "compiled/loom/", "") <> ".gleam"
  let assert Ok(_) =
    simplifile.create_directory_all(filepath.directory_name(out_file))
  let assert Ok(_) = simplifile.write(out_file, generated.code)

  io.println("  Compiled: " <> path <> " -> " <> out_file)
}
