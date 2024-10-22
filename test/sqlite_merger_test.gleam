import db_generator.{Bookmark}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn fictive_bookmarks_test() {
  let bookmarks = [
    Bookmark("www.google.fr", "Google desc"),
    Bookmark("www.gleam.run", "Gleam!"),
  ]

  use conn <- db_generator.fictive_bookmarks(bookmarks)
  db_generator.print_db(conn)
}
