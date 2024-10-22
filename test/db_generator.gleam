import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import sqlight.{type Connection, type Value}

pub type Bookmark {
  Bookmark(url: String, desc: String)
}

fn bookmark_value(bookmark: Bookmark) -> Value {
  let bookmark = "('" <> bookmark.url <> "', '" <> bookmark.desc <> "')"
  sqlight.text(bookmark)
}

pub fn print_db(conn: Connection) {
  let query = "SELECT id, url, desc FROM bookmarks;"
  let decoder = dynamic.tuple3(dynamic.int, dynamic.string, dynamic.string)
  let message = sqlight.query(query, on: conn, with: [], expecting: decoder)
  case message {
    Error(e) -> io.debug(e.message)
    Ok(results) ->
      results
      |> list.map(fn(x) { #(int.to_string(x.0), x.1, x.2) })
      |> list.map(fn(x) { [x.0, x.1, x.2] })
      |> list.map(string.join(_, " | "))
      |> string.join("\n")
      |> io.debug
  }
}

/// Generate a temporary in-memory bookmarks database. The database is
/// initialized with the given list of bookmarks.
///
/// # Examples
///
/// ```gleam
/// let bookmarks = [
///   Bookmark("www.google.fr", "Google desc"),
///   Bookmark("www.gleam.run", "Gleam!"),
/// ]
/// use conn <- db_generator.fictive_bookmarks(bookmarks)
/// ```
///
pub fn fictive_bookmarks(bookmarks: List(Bookmark), f: fn(Connection) -> a) -> a {
  use conn <- sqlight.with_connection(":memory:")

  // Create the database.
  let query =
    "
  CREATE TABLE bookmarks (
    id INTEGER PRIMARY KEY,
    url text,
    desc text
  );
  "
  let assert Ok(Nil) = sqlight.exec(query, conn)

  // Insert the bookmarks.
  let query =
    bookmarks
    |> list.map(fn(_) { "(?, ?)" })
    |> string.join(", ")
    |> string.append(";")
    |> string.append("INSERT INTO bookmarks (url, desc) VALUES ", _)
    |> io.debug

  let with =
    bookmarks
    |> list.map(fn(b) { [sqlight.text(b.url), sqlight.text(b.desc)] })
    |> list.flatten

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)

  // Use the function now that the database is created.
  f(conn)
}
