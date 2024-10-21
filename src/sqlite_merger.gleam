import gleam/dynamic
import gleam/io
import gleam/list
import gleam/set.{type Set}
import sqlight

fn list_items(db: String) -> Set(Int) {
  use conn <- sqlight.with_connection("file:" <> db)
  let query = "SELECT id, id FROM bookmarks;"
  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(ids) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)

  ids
  |> list.map(fn(x) { x })
  |> set.from_list
}

fn diff_items(db1: String, db2: String) -> Set(Int) {
  let items1 = list_items(db1)
  let items2 = list_items(db2)

  set.difference(items1, items2)
}

pub fn main() {
  let ids = list_items("bookmarks.db")
  io.println("Hey")
}
