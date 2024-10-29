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
  let generator = db_generator.bookmark_generator()
  let seeds_1 = list.range(from: -5, to: 5) |> list.map(seed.new)
  let seeds_2 = list.range(from: 0, to: 10) |> list.map(seed.new)

  // Generate two random list of bookmarks. Both lists have some elements in
  // common (because of common seeds).
  let bookmarks_1 =
    seeds_1
    |> list.map(random.sample(generator, _))
    |> list.shuffle

  let bookmarks_2 =
    seeds_2
    |> list.map(random.sample(generator, _))
    |> list.shuffle

  // Find the ids of the elements in bookmarks_2 that are not presents within
  // bookmarks_1.
  let added_ids =
    list.range(from: 1, to: list.length(seeds_2))
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

/// Test if some modified URLS are found.
///
pub fn modified_bookmarks_urls_test() {
  let generator = db_generator.bookmark_generator()
  let seeds = list.range(from: 0, to: 70) |> list.map(seed.new)
  let bookmarks = list.map(seeds, random.sample(generator, _))

  let modify_bookmark = fn(bookmark: Bookmark, seed: Seed) -> Bookmark {
    let randbool = random.int(0, 1)
    let randint = random.int(-1000, 1000)
    case random.sample(randbool, seed) == 1 {
      False -> bookmark
      True -> {
        let seed = random.sample(randint, seed) |> seed.new
        let other = random.sample(generator, seed)
        Bookmark(..bookmark, desc: other.desc, flags: other.flags)
      }
    }
  }
  let modified_bookmarks =
    bookmarks
    |> list.zip(seeds)
    |> list.map(fn(a) { modify_bookmark(a.0, a.1) })

  let bookmarks = list.take(bookmarks, 50)
  let modified_ids =
    list.range(from: 1, to: list.length(bookmarks))
    |> list.zip(list.zip(bookmarks, modified_bookmarks))
    |> list.filter(fn(a) { a.1.0 != a.1.1 })
    |> list.map(fn(a) { a.0 })

  use conn <- sqlight.with_connection(":memory:")
  let _ = db_generator.insert_bookmarks(bookmarks, "source", conn)
  let _ = db_generator.insert_bookmarks(modified_bookmarks, "target", conn)

  buku_merger.modified_urls(conn, "source", "target")
  |> list.sort(int.compare)
  |> should.equal(modified_ids)
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
