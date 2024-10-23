import gleam/dynamic
import gleam/string
import sqlight.{type Connection}

pub type Id =
  Int

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
    "
  SELECT t1.id FROM target as t1
  WHERE t1.url NOT IN
    ( SELECT t2.url FROM source as t2);
  "
    |> string.replace(each: "source", with: source)
    |> string.replace(each: "target", with: target)

  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(ids) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)
  ids
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
