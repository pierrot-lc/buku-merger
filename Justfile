bookmarks-properties:
  sqlite3 bookmarks.db "PRAGMA table_info(bookmarks);"

bookmarks-head:
  sqlite3 bookmarks.db "SELECT * FROM bookmarks WHERE bookmarks.id < 5;"

gleam-compile:
  gleam run -m gleescript
