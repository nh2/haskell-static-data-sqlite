# How to append static data to an executable using sqlite

Sometimes you want to ship some static data with a Haskell executable, such as:

* numerical lookup tables
* whitelists
* example data

This is especially relevant if you are building [static executables](https://github.com/nh2/static-haskell-nix) for as-self-contained-as-possible deployments, such as for Amazon Lambda, or to make life for your users easy.

This example code shows how you can use SQLite's [append VFS](https://sqlite.org/src/file/ext/misc/appendvfs.c), which

> allows an SQLite database to be appended onto the end of some other file, such as an executable

An SQLite database can be conveniently added to your Haskell executable using the `sqlite3` command line tool with the `--append` flag.
You can then open it from Haskell in read-only mode.

After opening it as shown in `app/Main.hs`, you can use it like any other SQLite DB, such as with the [`sqlite-simple`](https://hackage.haskell.org/package/sqlite-simple) package.


## Usage

Build the example `exe` using `stack build`.

Use `sqlite3 --append` to append a DB with some sample static data to it:

```bash
sqlite3 --append $(stack path --dist-dir)/build/exe/exe \
  "CREATE TABLE testtable (field1 TEXT);
   INSERT INTO testtable (field1) VALUES ('hello'), ('world');"
```

Run `exe` to see that it successfully reads the data:

```bash
$ $(stack path --dist-dir)/build/exe/exe
Database contents:
"hello"
"world"
```


## How the `sqlite3` executable uses it

* [`#include appendvfs.c`](https://github.com/sqlite/sqlite/blob/14c98a4f4016bb60679535e3d2d9fe6c49bfe04a/src/shell.c.in#L994)
* Calling [`sqlite3_appendvfs_init(0,0,0)`](https://github.com/sqlite/sqlite/blob/14c98a4f4016bb60679535e3d2d9fe6c49bfe04a/src/shell.c.in#L10542)
* Documenting the [`--append FILE`](https://github.com/sqlite/sqlite/blob/14c98a4f4016bb60679535e3d2d9fe6c49bfe04a/src/shell.c.in#L3530) switch
* Passing the [`apndvfs`](https://github.com/sqlite/sqlite/blob/14c98a4f4016bb60679535e3d2d9fe6c49bfe04a/src/shell.c.in#L4200-L4202) open flag to `sqlite3_open_v2()`
  * You can also use the older `sqlite3_open()` with `?vfs=apndvfs` if `SQLITE_USE_URI` is enabled (it is enabled by default; [docs](https://www.sqlite.org/uri.html))


## Alternative approaches and comparison

There are other ways how you can include static data into your executables:

* TemplateHaskell like [`file-embed`](https://hackage.haskell.org/package/file-embed)
  * splices large `ByteString` `"literals"` into source code
  * can be slow at compile-time because the compiler has to parse it
  * can be not-so-fast at run-time because data structures (such as `Map`s) have to be re-parsed/deserialised from the ByteStrings (at startup)
  * changing the data requires recompilation
  * Use of TemplateHaskell can trigger [The `TH` recompilation problem](https://gist.github.com/nh2/14e653bcbdc7f40042da3755539e554a)
  * alternatively, you can avoid recompilation if the amont of Bytes to embed is constant, using [`dummySpace` and `injectFile`](https://hackage.haskell.org/package/file-embed-0.0.11.2/docs/Data-FileEmbed.html#g:3)
* At link time using a custom assembly script
  * Shown in Sylvain Henry's blog post ["Fast file embedding with GHC!"](https://hsyl20.fr/home/posts/2019-01-15-fast-file-embedding-with-ghc.html)
  * fast at compile-time
  * can be not-so-fast at run-time because data structures (such as `Map`s) have to be re-parsed/deserialised from the ByteStrings (at startup)
  * changing the data requires re-linking
* Storing serialised _compact regions_ using the above methods
  * Using `Data.Compact.Serialize` from [`compact`](https://hackage.haskell.org/package/compact-0.1.0.1)
  * fast at run-time because data structures (such as `Map`s) do not have to be re-parsed/deserialised
  * cannot store some data (e.g. crashes on `ByteStrings` because they are pinned memory)
  * very new and untested, recent bugs have been found (in 2019/2020)

The approach shown here:

* SQLite's `vfs=apndvfs`
  * fast at compile-time
  * fast at run-time because data structures (such as `Map`s) do not have to be re-parsed/deserialised
    * instead, SQL queries can be directly made
  * performance is that of SQLite
  * `sqlite3` can be used to inspect/manipulate the data (works on all platforms)
  * changing the data requires no recompilation or re-linking
  * requires linking in [`appendvfs.c`](https://sqlite.org/src/file/ext/misc/appendvfs.c) (see `.cabal` file)
