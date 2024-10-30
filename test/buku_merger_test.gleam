import buku_merger
import db_generator.{type Bookmark, Bookmark}
import gleam/dynamic
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should
import prng/random
import prng/seed.{type Seed}
import sqlight

pub fn main() {
  gleeunit.main()
}

/// Test if some added bookmarks are found. After they are found, they are
/// added back to the original table and test if both tables are equals.
///
pub fn added_bookmarks_test() {
  let seeds_1 = list.range(from: 0, to: 50) |> list.map(seed.new)
  let seeds_2 = list.range(from: 51, to: 100) |> list.map(seed.new)
  let generator = random.sample(db_generator.bookmark_generator(), _)

  let bookmarks_1 = seeds_1 |> list.map(generator)
  let bookmarks_2 = seeds_2 |> list.map(generator)
  let bookmarks_2 = list.concat([bookmarks_1, bookmarks_2]) |> list.shuffle

  // Find the ids of the elements in bookmarks_2 that are not presents within
  // bookmarks_1.
  let added_ids =
    list.range(from: 1, to: list.length(bookmarks_2))
    |> list.zip(bookmarks_2)
    |> list.filter(fn(a) { !list.contains(bookmarks_1, a.1) })
    |> list.map(fn(a) { a.0 })
    |> list.sort(int.compare)

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks_1, "source", conn)
  let _ = db_generator.insert_bookmarks(bookmarks_2, "target", conn)

  buku_merger.added_urls(conn, "source", "target")
  |> list.sort(int.compare)
  |> should.equal(added_ids)

  let _ =
    buku_merger.insert_ids(conn, added_ids, source: "target", target: "source")
  buku_merger.added_urls(conn, "source", "target")
  |> should.equal([])
}

/// Test if some modified URLS are found. They are copied back and test if both
/// tables are equals.
///
pub fn modified_bookmarks_urls_test() {
  let seeds = list.range(from: 0, to: 70) |> list.map(seed.new)
  let generator = random.sample(db_generator.bookmark_generator(), _)
  let bookmarks = seeds |> list.map(generator)

  let modify_bookmark = fn(bookmark: Bookmark, seed: Seed) -> Bookmark {
    let modify =
      seed
      |> random.sample(random.int(-1000, 1000), _)
      |> seed.new
      |> random.sample(random.int(0, 1), _)

    let other =
      seed
      |> random.sample(random.int(-1000, 1000), _)
      |> seed.new
      |> generator()

    case modify == 1 {
      True -> Bookmark(..bookmark, desc: other.desc, flags: other.flags)
      False -> bookmark
    }
  }

  let modified_bookmarks =
    list.zip(bookmarks, seeds)
    |> list.map(fn(a) { modify_bookmark(a.0, a.1) })

  let ids = list.range(from: 1, to: list.length(modified_bookmarks))
  let modified_ids =
    list.zip(ids, modified_bookmarks)
    |> list.filter(fn(b) { !list.contains(bookmarks, b.1) })
    |> list.map(fn(b) { b.0 })
    |> list.sort(int.compare)

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "source", conn)
  let _ = db_generator.insert_bookmarks(modified_bookmarks, "target", conn)

  buku_merger.modified_urls(conn, "source", "target")
  |> list.sort(int.compare)
  |> should.equal(modified_ids)

  let _ = buku_merger.modify_ids(conn, modified_ids, "source", "target")
  buku_merger.modified_urls(conn, "source", "target")
  |> should.equal([])
}

/// Test if the removal of some rows is done correctly.
///
pub fn remove_ids_test() {
  let seeds = list.range(from: 0, to: 70) |> list.map(seed.new)
  let generator = random.sample(db_generator.bookmark_generator(), _)
  let bookmarks = seeds |> list.map(generator)

  let remove_ids = seeds |> list.map(random.sample(random.int(0, 1), _))
  let remove_ids =
    remove_ids
    |> list.zip(list.range(from: 1, to: list.length(remove_ids)))
    |> list.filter(fn(a) { a.0 == 1 })
    |> list.map(fn(a) { a.1 })

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "source", conn)
  let _ = db_generator.insert_bookmarks(bookmarks, "target", conn)

  let _ = buku_merger.remove_ids(conn, remove_ids, "source")
  buku_merger.added_urls(conn, "source", "target")
  |> should.equal(remove_ids)
}

/// Test the construction of a fictive bookmarks table.
///
pub fn fictive_bookmarks_test() {
  let generator = db_generator.bookmark_generator()
  let seeds = list.range(from: 0, to: 70) |> list.map(seed.new)
  let bookmarks = list.map(seeds, random.sample(generator, _))

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "bookmarks", conn)
  let query = "SELECT url, metadata, tags, desc, flags FROM bookmarks;"
  let decoder =
    dynamic.tuple5(
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.int,
    )
  let assert Ok(res) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)

  res
  |> list.map(fn(b) { Bookmark(b.0, b.1, b.2, b.3, b.4) })
  |> should.equal(bookmarks)
}
