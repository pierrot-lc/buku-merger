import argv
import gleam/dynamic
import gleam/list
import gleam/result
import gleam/string
import simplifile
import sqlight.{type Connection}

pub type Id =
  Int

pub type BookmarkTable =
  String

/// Find the URLs present in the target table but not in source table.
///
pub fn added_urls(
  conn: Connection,
  source source: BookmarkTable,
  target target: BookmarkTable,
) -> List(Id) {
  let query =
    "
  SELECT t1.id FROM {target} AS t1
  WHERE t1.url NOT IN
    ( SELECT t2.url FROM {source} AS t2 );
  "
    |> string.replace(each: "{source}", with: source)
    |> string.replace(each: "{target}", with: target)

  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(ids) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)
  ids
}

/// Find the modified entries of the target table w.r.t. the source table.
///
/// An entry is considered modified if the row have the same URL and ID but the
/// rest of the row is different.
///
pub fn modified_urls(
  conn: Connection,
  source source: BookmarkTable,
  target target: BookmarkTable,
) -> List(Id) {
  let query =
    "
  SELECT t1.id FROM {target} AS t1
  INNER JOIN {source} AS t2 ON t1.id=t2.id AND t1.url=t2.url
  WHERE (
    t1.desc!=t2.desc OR
    t1.flags!=t2.flags OR
    t1.metadata!=t2.metadata OR
    t1.tags!=t2.tags
  );
  "
    |> string.replace(each: "{source}", with: source)
    |> string.replace(each: "{target}", with: target)

  let decoder = dynamic.element(0, dynamic.int)
  let assert Ok(ids) =
    sqlight.query(query, on: conn, with: [], expecting: decoder)
  ids
}

/// Insert the rows from the source table to the target table.
///
pub fn insert_ids(
  conn: Connection,
  ids: List(Id),
  source source: BookmarkTable,
  target target: BookmarkTable,
) {
  let query =
    "
  INSERT INTO {target} (URL, metadata, tags, desc, flags)
  SELECT URL, metadata, tags, desc, flags
  FROM {source} as s
  WHERE s.id IN
  "
    |> string.replace(each: "{source}", with: source)
    |> string.replace(each: "{target}", with: target)

  // Add "(?, ?, ...)" for each id.
  let query =
    ids
    |> list.map(fn(_) { "?" })
    |> string.join(", ")
    |> string.append(" (", _)
    |> string.append(");")
    |> string.append(query, _)

  let with =
    ids
    |> list.map(fn(i) { sqlight.int(i) })

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)
}

/// Copy the rows from the source table to the target table.
///
pub fn modify_ids(
  conn: Connection,
  ids: List(Id),
  source source: BookmarkTable,
  target target: BookmarkTable,
) {
  let query =
    "
  UPDATE {target} AS t1
  SET metadata = (SELECT metadata FROM {source} AS t2 WHERE t2.id = t1.id),
      tags = (SELECT tags FROM {source} AS t2 WHERE t2.id = t1.id),
      desc = (SELECT desc FROM {source} AS t2 WHERE t2.id = t1.id),
      flags = (SELECT flags FROM {source} AS t2 WHERE t2.id = t1.id)
  WHERE t1.id IN
  "
    |> string.replace(each: "{source}", with: source)
    |> string.replace(each: "{target}", with: target)

  let query =
    ids
    |> list.map(fn(_) { "?" })
    |> string.join(", ")
    |> string.append(" (", _)
    |> string.append(");")
    |> string.append(query, _)

  let with =
    ids
    |> list.map(fn(i) { sqlight.int(i) })

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)
}

/// Remove the rows from the table.
///
pub fn remove_ids(conn: Connection, ids: List(Id), table: BookmarkTable) {
  let query =
    "
  DELETE FROM {table} as t
  WHERE t.id in
  "
    |> string.replace(each: "{table}", with: table)

  let query =
    ids
    |> list.map(fn(_) { "?" })
    |> string.join(", ")
    |> string.append(" (", _)
    |> string.append(");")
    |> string.append(query, _)

  let with =
    ids
    |> list.map(fn(i) { sqlight.int(i) })

  let assert Ok(_) =
    sqlight.query(query, on: conn, with: with, expecting: dynamic.dynamic)
}

/// Attach the multiple databases into a single SQLite connection and provide
/// the associated bookmark tables.
///
pub fn attach_dbs(
  base: String,
  current: String,
  other: String,
  f: fn(Connection, BookmarkTable, BookmarkTable, BookmarkTable) -> a,
) -> a {
  use conn <- sqlight.with_connection(current)

  let query =
    "ATTACH DATABASE '{table}' AS base;" |> string.replace("{table}", base)
  let assert Ok(Nil) = sqlight.exec(query, on: conn)

  let query =
    "ATTACH DATABASE '{table}' AS other;" |> string.replace("{table}", other)
  let assert Ok(Nil) = sqlight.exec(query, on: conn)

  // Point to the bookmarks tables.
  let #(base, current, other) = #(
    "base.bookmarks",
    "main.bookmarks",
    "other.bookmarks",
  )
  f(conn, base, current, other)
}

/// Finds the added and modified bookmarks between the "current" table, the
/// "other" table and the "base" table. Then the modifications are applied to
/// the "current" table.
///
pub fn bookmarks_diff(
  conn: Connection,
  base _base: BookmarkTable,
  current current: BookmarkTable,
  other other: BookmarkTable,
) {
  let added = added_urls(conn, source: current, target: other)
  let modified = modified_urls(conn, source: current, target: other)

  let _ = modify_ids(conn, modified, source: other, target: current)
  let _ = insert_ids(conn, added, source: other, target: current)
}

pub fn main() {
  // Check input args.
  let #(base, current, other) = case argv.load().arguments {
    [base, current, other] -> #(base, current, other)
    _ -> panic as "Usage: ./buku_merger <base> <current> <other>"
  }

  // Make sure the files exists.
  let exists = case
    [base, current, other] |> list.map(simplifile.is_file) |> result.all
  {
    Error(_) -> panic as "File error!"
    Ok(exists) -> exists
  }

  case exists |> list.all(fn(a) { a }) {
    False -> panic as "One of the input file does not exist!"
    True -> Nil
  }

  use conn, base, current, other <- attach_dbs(base, current, other)
  let _ = bookmarks_diff(conn, base, current, other)
}
