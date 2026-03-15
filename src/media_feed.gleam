import gleam/int
import gleam/list
import gleam/string
import models/media.{type MediaItem, type MediaType, LivePhoto, MediaItem, Photo, Video}

const user_pool = ["Alice", "Bob", "Charlie", "Diana", "Erik", "Fiona", "George", "Hannah"]

const place_pool = [
  "Prague, Czech Republic", "Paris, France", "Tokyo, Japan",
  "New York, USA", "Barcelona, Spain", "Rome, Italy",
  "London, UK", "Berlin, Germany", "Sydney, Australia",
  "Kyoto, Japan", "Vienna, Austria", "Amsterdam, Netherlands",
]

const year_pool = ["2024", "2025", "2026"]

const month_pool = [
  "01", "02", "03", "04", "05", "06",
  "07", "08", "09", "10", "11", "12",
]

const day_pool = [
  "01", "05", "08", "12", "15", "18", "21", "24", "27",
]

pub fn generate_feed() -> List(MediaItem) {
  int.range(from: 0, to: 27, with: [], run: fn(acc, i) {
    [generate_item(i), ..acc]
  })
  |> list.reverse
  |> assign_layout
  |> list.sort(fn(a, b) { string.compare(b.date_taken, a.date_taken) })
}

/// Assigns CSS position + size classes per the collage app's 14-slot pattern.
///
/// From iOS setSizeForCell — each slot uses big or small image size
/// and positions it at a specific anchor within the cell:
///   0:  big,   bottom-left       8:  big,   bottom-right
///   1:  small, center-right      9:  big,   center-right
///   2:  small, bottom-right     10:  small, center-center
///   3:  small, center-center    11:  small, bottom-left
///   4:  small, center-left      12:  small, top-center
///   5:  small, center-bottom    13:  small, bottom-right
///   6:  small, top-right
///   7:  small, center-center
fn assign_layout(items: List(MediaItem)) -> List(MediaItem) {
  list.index_map(items, fn(item, idx) {
    let slot = idx % 14

    // 2-column layout matching the app screenshot:
    // Row pattern repeats every 6 items (3 rows of 2).
    // Each row has one bigger and one smaller image,
    // scattered to different corners/edges.
    let cell_class = case slot % 6 {
      // Row 1: left=small bottom-left, right=big top-right
      0 -> "pos-bl size-small"
      1 -> "pos-tr size-big"
      // Row 2: left=small center, right=big center-right
      2 -> "pos-cc size-small"
      3 -> "pos-cr size-big"
      // Row 3: left=small top-left, right=big bottom-right
      4 -> "pos-tl size-small"
      5 -> "pos-br size-big"
      _ -> "pos-cc size-small"
    }

    MediaItem(..item, cell_class:)
  })
}

const aspect_ratios = [
  #(400, 560),  // portrait tall
  #(500, 350),  // landscape wide
  #(450, 450),  // square
  #(380, 540),  // portrait
  #(550, 380),  // landscape
  #(420, 600),  // portrait tall
  #(600, 400),  // landscape wide
  #(480, 480),  // square
  #(360, 520),  // portrait
  #(520, 340),  // landscape wide
]

fn generate_item(id: Int) -> MediaItem {
  let media_type = random_media_type()
  let tagged = random_tagged_users()
  let place = random_from(place_pool)
  let date = random_date()

  let ratio_idx = id % 10
  let assert [#(w, h), ..] = list.drop(aspect_ratios, ratio_idx)

  MediaItem(
    id:,
    media_type:,
    url: "https://picsum.photos/seed/col"
      <> int.to_string(id)
      <> "/"
      <> int.to_string(w)
      <> "/"
      <> int.to_string(h),
    date_taken: date,
    tagged_users: tagged,
    tagged_users_display: string.join(tagged, ", "),
    place:,
    media_type_label: media_type_to_label(media_type),
    cell_class: "",
  )
}

fn media_type_to_label(mt: MediaType) -> String {
  case mt {
    Photo -> "Photo"
    LivePhoto -> "Live"
    Video -> "Video"
  }
}

fn random_media_type() -> MediaType {
  let n = int.random(10)
  case n {
    0 | 1 -> LivePhoto
    2 -> Video
    _ -> Photo
  }
}

fn random_tagged_users() -> List(String) {
  let count = 1 + int.random(3)
  int.range(from: 0, to: count, with: [], run: fn(acc, _) {
    [random_from(user_pool), ..acc]
  })
  |> list.unique
}

fn random_date() -> String {
  let year = random_from(year_pool)
  let month = random_from(month_pool)
  let day = random_from(day_pool)
  year <> "-" <> month <> "-" <> day
}

fn random_from(items: List(String)) -> String {
  let len = list.length(items)
  let idx = int.random(len)
  case list.drop(items, idx) {
    [item, ..] -> item
    [] -> {
      let assert [first, ..] = items
      first
    }
  }
}

pub fn search_by_user(
  items: List(MediaItem),
  query: String,
) -> List(MediaItem) {
  let q = string.lowercase(query)
  list.filter(items, fn(item) {
    list.any(item.tagged_users, fn(user) {
      string.contains(string.lowercase(user), q)
    })
  })
}

pub fn search_by_place(
  items: List(MediaItem),
  query: String,
) -> List(MediaItem) {
  let q = string.lowercase(query)
  list.filter(items, fn(item) {
    string.contains(string.lowercase(item.place), q)
  })
}
