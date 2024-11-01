# Buku Merger

Custom git driver to handle merge conflicts of your [buku](buku) bookmarks.

I had the idea of using git to sync my bookmarks, _which are stored as a
SQLite database_. The first merge conflict proved me that it was a bad idea. But
I am lazy and I don't want to handle the sync service myself, so I made this
tool to handle the conflicts automatically for me so that I can keep using git
as a "cloud service" for my bookmarks.

Feel free to use it for your own buku git repository!

## Installation

**From source:**

1. Clone the repository.
1. Install [Gleam](gleam).
1. Run `gleam run -m gleescript`.
1. Add the generated `buku_merger` to your `PATH`.

**Using Nix:**

This repository includes a flake which provides the package. You can test the
package directly by running:

```bash
nix run "github:pierrot-lc/buku-merger"
```

## How to Use

The tool expects the following:

```bash
buku_merger <base> <current> <other>
```

Where:

- `<current>` is the local version of the bookmarks database,
- `<other>` is the remote version conflicting with your `<current>` version,
  and
- `<base>` is the latest common ancestor between the two conflicting databases.

To use the tool automatically when there's a conflict, you need to add the driver
to your git configuration:

```gitconfig
# .gitconfig or config
[merge "buku-driver"]
    name = "Custom buku merge driver, handling the bookmarks SQLite database"
    driver = buku_merger %O %A %B
    recursive = binary
```

Add those lines either in your `~/.config/git/config` globally or in your buku
repository at `.git/config`.

Then, specify in your buku repository that you want to use that driver for
bookmark conflicts:

```gitattributes
# .gitattributes
bookmarks.db merge=buku-driver
```

Place this file at the root of your buku repository.

## How it Works?

The merge conflict is handled in two phases:

1. Identify rows modified in `<other>` compared to `<base>` and apply those
   modifications to `<current>`.
1. Find new rows in `<other>` that do not exist in `<current>` and add them.
1. ~~Find removed rows from `<other>` that are still present in `<base>` and
   remove them from `<current>`.~~

The final file `<current>` is used by git as the merged version.

_I no longer delete the bookmarks, as it is too easy to mess everything up._

## Shoutouts

This tool is made using the awesome [Gleam](gleam) language and uses
[sqlight](sqlight) to interface with SQLite.

The flake uses [nix-gleam](nix-gleam) to generate the package derivation
effortlessly.

[buku]: https://github.com/jarun/buku
[gleam]: https://gleam.run/
[nix-gleam]: https://github.com/arnarg/nix-gleam
[sqlight]: https://github.com/lpil/sqlight
