import gleam/dynamic
import gleam/list
import gleam/string
import sqlight.{type Connection}

pub type Id {
  Id(Int)
}

pub type TableDiff {
  TableDiff(added: List(Id), removed: List(Id), modified: List(Id))
}

/// Find the element present in the target table but not in source table. An
/// element identified by its ID and URL column value. Returns the primary IDs of the
/// selected rows.
pub fn bookmarks_added(
  conn: Connection,
  source source: String,
  target target: String,
) -> List(Id) {
  let query =
    [
      "SELECT t1.id FROM",
      target,
      "as t1 JOIN",
      source,
      "as t2 on t1.id = t2.id WHERE t1.url != t2.url;",
    ]
    |> string.join(" ")
  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(ids) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)
  ids |> list.map(fn(id) { Id(id) })
}

pub fn bookmarks_diff(
  conn: Connection,
  source: String,
  target: String,
) -> TableDiff {
  todo
}

pub fn main() {
  todo
}
