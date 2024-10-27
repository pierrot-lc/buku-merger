import buku_merger
import db_generator.{Bookmark}
import gleam/dynamic
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should
import sqlight

pub fn main() {
  gleeunit.main()
}

pub fn added_bookmarks_test() {
  let bookmarks_1 = [
    Bookmark("www.google.fr", "Google", ",search,", "Google website", 0),
    Bookmark("www.gleam.run", "Gleam", ",fp,", "Try Gleam online!", 0),
  ]
  let bookmarks_2 = [
    Bookmark("www.google.fr", "Google", ",search,", "Google website", 0),
    Bookmark("www.gleam.run", "Gleam", ",fp,", "Try Gleam online!", 0),
    Bookmark("overfitted.dev", "Overfitted", ",blog,", "My personal website", 0),
  ]
  let added_ids = [3]

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks_1, "source", conn)
  let _ = db_generator.insert_bookmarks(bookmarks_2, "target", conn)

  buku_merger.added_urls(conn, "source", "target")
  |> list.sort(int.compare)
  |> should.equal(added_ids)
}

pub fn modified_bookmarks_test() {
  let bookmarks_1 = [
    Bookmark("www.google.fr", "Google", ",search,", "Google website", 0),
    Bookmark("www.gleam.run", "Gleam", ",fp,", "Try Gleam!", 0),
    Bookmark("overfitted.dev", "Overfitted", ",blog,", "My personal website", 0),
  ]
  let bookmarks_2 = [
    Bookmark("www.google.fr", "Google", ",search,", "Google website", 0),
    Bookmark("www.gleam.run", "Gleam", ",fp,", "Try Gleam online!", 0),
    Bookmark("overfitted.dev", "Overfitted", ",blog,", "My personal website", 0),
  ]
  let added_ids = [2]

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks_1, "source", conn)
  let _ = db_generator.insert_bookmarks(bookmarks_2, "target", conn)

  buku_merger.modified_urls(conn, "source", "target")
  |> list.sort(int.compare)
  |> should.equal(added_ids)
}

/// Test the construction of a fictive bookmarks table.
pub fn fictive_bookmarks_test() {
  let bookmarks = [
    Bookmark("www.google.fr", "Google", ",search,", "Google website", 0),
    Bookmark("www.gleam.run", "Gleam", ",fp,", "Try Gleam online!", 0),
  ]

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "bookmarks", conn)
  let query = "SELECT url, metadata, tags, desc, flags FROM bookmarks;"
  let decoder = db_generator.bookmark_decoder
  let assert Ok(res) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)

  res
  |> should.equal(bookmarks)
}
