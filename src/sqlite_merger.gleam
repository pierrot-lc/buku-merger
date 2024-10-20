import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import sqlight

pub fn main() {
  io.println("Hello from sqlite_merger!")

  use conn <- sqlight.with_connection("file:bookmarks.db")
  let query = "SELECT id, url FROM bookmarks;"
  let decoder = dynamic.tuple2(dynamic.int, dynamic.string)
  let message = case
    sqlight.query(query, on: conn, with: [], expecting: decoder)
  {
    Error(e) -> e.message
    Ok(res) ->
      res
      |> list.map(fn(x) { x.0 })
      |> list.map(fn(x) { int.to_string(x) })
      |> list.map(fn(x) { x <> " " })
      |> string.concat
  }
  io.println(message)
}
