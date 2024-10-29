import buku_merger.{type BookmarkTable}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import prng/random.{type Generator}
import sqlight.{type Connection}

pub type Bookmark {
  Bookmark(
    url: String,
    metadata: String,
    tags: String,
    desc: String,
    flags: Int,
  )
}

/// Generates bookmarks with random strings and integers.
///
pub fn bookmark_generator() -> Generator(Bookmark) {
  let string_generator = random.fixed_size_string(5)
  let int_generator = random.int(0, 10)

  use a, b, c, d, e <- random.map5(
    string_generator,
    string_generator,
    string_generator,
    string_generator,
    int_generator,
  )
  Bookmark(a, b, c, d, e)
}

/// Prints the content of the given table.
///
pub fn print_db(table: BookmarkTable, conn: Connection) {
  let query =
    "SELECT id, url, desc FROM {table};"
    |> string.replace("{table}", table)
  let decoder = dynamic.tuple3(dynamic.int, dynamic.string, dynamic.string)
  let message = sqlight.query(query, on: conn, with: [], expecting: decoder)

  case message {
    Error(e) -> io.println(e.message)
    Ok(results) ->
      results
      |> list.map(fn(x) { #(int.to_string(x.0), x.1, x.2) })
      |> list.map(fn(x) { [x.0, x.1, x.2] })
      |> list.map(string.join(_, " | "))
      |> string.join("\n")
      |> io.println
  }
}

/// Insert the bookmarks to the table.
///
/// If the table does not exists, it will be created.
///
/// ## Examples
///
/// ```gleam
/// use conn <- sqlight.with_connection(":memory:")
/// let table = "bookmarks"
/// let bookmarks = [
///   Bookmark("https://gleam.run/", "The Gleam website!", "", "", 0),
///   Bookmark("https://tour.gleam.run/", "Gleam Language Tour", "", "", 0),
/// ]
///
/// let _ = insert_bookmarks(bookmarks, table, conn)
/// ````
///
pub fn insert_bookmarks(
  bookmarks: List(Bookmark),
  table: BookmarkTable,
  conn: Connection,
) {
  // Create the table if necessary.
  let query =
    "
  CREATE TABLE IF NOT EXISTS {table} (
    id INTEGER PRIMARY KEY,
    URL TEXT NOT NULL,
    metadata TEXT DEFAULT '',
    tags TEXT DEFAULT ',',
    desc TEXT DEFAULT '',
    flags INTEGER DEFAULT 0
  );
    "
    |> string.replace("{table}", table)
  let assert Ok(Nil) = sqlight.exec(query, conn)

  // Insert the bookmarks.
  let query =
    bookmarks
    |> list.map(fn(_) { "(?, ?, ?, ?, ?)" })
    |> string.join(",\n")
    |> string.append(";")
    |> string.append(
      "INSERT INTO {table} (URL, metadata, tags, desc, flags) VALUES "
        |> string.replace("{table}", table),
      _,
    )

  let with =
    bookmarks
    |> list.map(fn(a) {
      [
        sqlight.text(a.url),
        sqlight.text(a.metadata),
        sqlight.text(a.tags),
        sqlight.text(a.desc),
        sqlight.int(a.flags),
      ]
    })
    |> list.flatten

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)
}
