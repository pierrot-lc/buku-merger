import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import sqlight.{type Connection, type Value}

pub type Bookmark {
  Bookmark(
    url: String,
    metadata: String,
    tags: String,
    desc: String,
    flags: Int,
  )
}

pub fn bookmark_to_sqlight_args(b: Bookmark) -> List(Value) {
  [
    sqlight.text(b.url),
    sqlight.text(b.metadata),
    sqlight.text(b.tags),
    sqlight.text(b.desc),
    sqlight.int(b.flags),
  ]
}

/// Make sure the query is fetching the columns in the right order!
pub fn bookmark_decoder(d: Dynamic) -> Result(Bookmark, List(DecodeError)) {
  let decoder =
    dynamic.tuple5(
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.int,
    )
  case decoder(d) {
    Ok(b) -> Ok(Bookmark(b.0, b.1, b.2, b.3, b.4))
    Error(e) -> Error(e)
  }
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
pub fn insert_bookmarks(
  bookmarks: List(Bookmark),
  table: String,
  conn: Connection,
) {
  // Create the table if necessary.
  let query =
    "
  CREATE TABLE IF NOT EXISTS table_name (
    id INTEGER PRIMARY KEY,
    URL TEXT NOT NULL,
    metadata TEXT DEFAULT '',
    tags TEXT DEFAULT ',',
    desc TEXT DEFAULT '',
    flags INTEGER DEFAULT 0
  );
    "
    |> string.replace(each: "table_name", with: table)
  let assert Ok(Nil) = sqlight.exec(query, conn)

  // Insert the bookmarks.
  let query =
    bookmarks
    |> list.map(fn(_) { "(?, ?, ?, ?, ?)" })
    |> string.join(",\n")
    |> string.append(";")
    |> string.append(
      "INSERT INTO " <> table <> " (URL, metadata, tags, desc, flags) VALUES ",
      _,
    )

  let with =
    bookmarks
    |> list.map(bookmark_to_sqlight_args)
    |> list.flatten

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)
}
