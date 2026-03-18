/// Supabase Storage + Database client for photo uploads.

import gleam/dynamic/decode
import envoy
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type Config {
  Config(url: String, key: String, bucket: String)
}

pub type Photo {
  Photo(
    id: Int,
    storage_path: String,
    people: String,
    place: String,
    date_taken: String,
  )
}

pub fn get_config() -> Result(Config, String) {
  use url <- result.try(
    envoy.get("SUPABASE_URL")
    |> result.replace_error("SUPABASE_URL not set"),
  )
  use key <- result.try(
    envoy.get("SUPABASE_KEY")
    |> result.replace_error("SUPABASE_KEY not set"),
  )
  let bucket = envoy.get("SUPABASE_BUCKET") |> result.unwrap("photos")
  Ok(Config(url:, key:, bucket:))
}

/// Upload a file to Supabase Storage.
pub fn upload_image(
  config: Config,
  path: String,
  content_type: String,
  body: BitArray,
) -> Result(Nil, String) {
  let url =
    config.url
    <> "/storage/v1/object/"
    <> config.bucket
    <> "/"
    <> path
  let assert Ok(req) = request.to(url)
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("authorization", "Bearer " <> config.key)
    |> request.set_header("apikey", config.key)
    |> request.set_header("content-type", content_type)
    |> request.set_header("x-upsert", "true")
    |> request.set_body(body)
  case httpc.send_bits(req) {
    Ok(resp) ->
      case resp.status {
        200 | 201 -> Ok(Nil)
        status ->
          Error(
            "Storage upload failed with status " <> int.to_string(status),
          )
      }
    Error(_) -> Error("Storage upload HTTP request failed")
  }
}

/// Insert photo metadata into the photos table via PostgREST.
pub fn insert_photo(
  config: Config,
  storage_path: String,
  people: String,
  place: String,
  date_taken: String,
) -> Result(Nil, String) {
  let url = config.url <> "/rest/v1/photos"
  let body =
    json.object([
      #("storage_path", json.string(storage_path)),
      #("people", json.string(people)),
      #("place", json.string(place)),
      #("date_taken", json.string(date_taken)),
    ])
    |> json.to_string
  let assert Ok(req) = request.to(url)
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_header("apikey", config.key)
    |> request.set_header("authorization", "Bearer " <> config.key)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("prefer", "return=representation")
    |> request.set_body(body)
  case httpc.send(req) {
    Ok(resp) ->
      case resp.status {
        200 | 201 -> Ok(Nil)
        status ->
          Error("DB insert failed with status " <> int.to_string(status))
      }
    Error(_) -> Error("DB insert HTTP request failed")
  }
}

/// List all photos from the photos table.
pub fn list_photos(config: Config) -> Result(List(Photo), String) {
  let url = config.url <> "/rest/v1/photos?select=*&order=created_at.desc"
  let assert Ok(req) = request.to(url)
  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_header("apikey", config.key)
    |> request.set_header("authorization", "Bearer " <> config.key)
  case httpc.send(req) {
    Ok(resp) -> {
      let decoder =
        decode.list({
          use id <- decode.field("id", decode.int)
          use storage_path <- decode.field("storage_path", decode.string)
          use people <- decode.field("people", decode.string)
          use place <- decode.field("place", decode.string)
          use date_taken <- decode.field("date_taken", decode.string)
          decode.success(Photo(id:, storage_path:, people:, place:, date_taken:))
        })
      json.parse(resp.body, decoder)
      |> result.replace_error("Failed to parse photos response")
    }
    Error(_) -> Error("List photos HTTP request failed")
  }
}

/// Construct the public URL for a stored image.
pub fn public_url(config: Config, path: String) -> String {
  config.url
  <> "/storage/v1/object/public/"
  <> config.bucket
  <> "/"
  <> path
}

/// Upload a file from a temp path to Supabase Storage.
pub fn upload_from_path(
  config: Config,
  temp_path: String,
  storage_path: String,
  content_type: String,
) -> Result(Nil, String) {
  case simplifile.read_bits(temp_path) {
    Ok(body) -> upload_image(config, storage_path, content_type, body)
    Error(_) -> Error("Failed to read uploaded file")
  }
}

/// Guess MIME type from filename extension.
pub fn guess_content_type(filename: String) -> String {
  let lower = string.lowercase(filename)
  case string.split(lower, ".") |> list.last {
    Ok("heic") -> "image/heic"
    Ok("heif") -> "image/heif"
    Ok("png") -> "image/png"
    Ok("gif") -> "image/gif"
    Ok("webp") -> "image/webp"
    Ok("jpg") | Ok("jpeg") -> "image/jpeg"
    _ -> "image/jpeg"
  }
}
