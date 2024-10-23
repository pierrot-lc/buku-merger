import db_generator.{Bookmark}
import gleam/dynamic
import gleam/list
import gleam/order
import gleeunit
import gleeunit/should
import sqlight
import sqlite_merger.{type Id}

pub fn main() {
  gleeunit.main()
}

pub fn added_bookmarks_test() {
  let bookmarks_1 = [
    Bookmark("www.google.fr", "Google website"),
    Bookmark("www.gleam.run", "Try Gleam online!"),
  ]
  let bookmarks_2 = [
    Bookmark("www.google.fr", "Google website"),
    Bookmark("www.gleam.run", "Try Gleam online!"),
    Bookmark("overfitted.dev", "My personal website."),
  ]
  let added_ids = [3]

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks_1, "source", conn)
  let _ = db_generator.insert_bookmarks(bookmarks_2, "target", conn)

  sqlite_merger.bookmarks_added(conn, "source", "target")
  |> list.sort(fn(a, b) {
    case a < b {
      True -> order.Lt
      False -> order.Gt
    }
  })
  |> should.equal(added_ids)
}

/// Test the construction of a fictive bookmarks table.
pub fn fictive_bookmarks_test() {
  let bookmarks = [
    Bookmark("www.google.fr", "Google desc"),
    Bookmark("www.gleam.run", "Gleam!"),
  ]

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "bookmarks", conn)
  let query = "SELECT url, desc FROM bookmarks;"
  let decoder = dynamic.tuple2(dynamic.string, dynamic.string)
  let assert Ok(res) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)

  res
  |> list.map(fn(b) { Bookmark(b.0, b.1) })
  |> should.equal(bookmarks)
}
