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

pub type TableDiff {
  TableDiff(added: List(Id), removed: List(Id), modified: List(Id))
}

pub type MergeArgs {
  MergeArgs(base: BookmarkTable, current: BookmarkTable, other: BookmarkTable)
}

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

/// Compute the bookmarks diff.
///
pub fn bookmarks_diff(conn: Connection, args: MergeArgs) -> TableDiff {
  let added = added_urls(conn, source: args.current, target: args.other)
  let modified = modified_urls(conn, source: args.other, target: args.current)
  let removed = added_urls(conn, source: args.current, target: args.base)

  TableDiff(added, removed, modified)
}

pub fn apply_diff(conn: Connection, args: MergeArgs, diff: TableDiff) {
  let _ = insert_ids(conn, diff.added, source: args.other, target: args.current)
}

/// Attach the multiple databases into a single SQLite connection and provide
/// the associated bookmark tables.
///
pub fn attach_dbs(
  base: String,
  current: String,
  other: String,
  f: fn(Connection, MergeArgs) -> a,
) -> a {
  use conn <- sqlight.with_connection(current)

  let query =
    "ATTACH DATABASE '{table}' AS base;" |> string.replace("{table}", base)
  let assert Ok(Nil) = sqlight.exec(query, on: conn)

  let query =
    "ATTACH DATABASE '{table}' AS other;" |> string.replace("{table}", other)
  let assert Ok(Nil) = sqlight.exec(query, on: conn)

  // Point to the bookmarks tables.
  let args = MergeArgs("base.bookmarks", "main.bookmarks", "other.bookmarks")

  f(conn, args)
}

pub fn main() {
  let assert Ok(#(base, current, other)) = case argv.load().arguments {
    [base, current, other] -> Ok(#(base, current, other))
    _ -> Error("Usage: ./buku_merger <base> <current> <other>")
  }

  // Check if input files exist.
  let assert Ok(are_files) =
    [base, current, other]
    |> list.map(simplifile.is_file)
    |> result.all

  let assert Ok(Nil) = case are_files |> list.all(fn(b) { b }) {
    True -> Ok(Nil)
    False -> Error("Some of the input files do not exist")
  }

  use conn, args <- attach_dbs(base, current, other)
  let diff = bookmarks_diff(conn, args)
  let _ = apply_diff(conn, args, diff)
}
