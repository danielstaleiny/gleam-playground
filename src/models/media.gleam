pub type MediaType {
  Photo
  LivePhoto
  Video
}

/// cell_class: CSS classes for position + size (e.g. "pos-bl size-big")
pub type MediaItem {
  MediaItem(
    id: Int,
    media_type: MediaType,
    url: String,
    date_taken: String,
    tagged_users: List(String),
    tagged_users_display: String,
    place: String,
    media_type_label: String,
    cell_class: String,
  )
}
