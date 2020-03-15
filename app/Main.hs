{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ForeignFunctionInterface #-}

import           Control.Monad (when)
import           Data.Foldable (for_)
import           Database.SQLite.Simple
import           Database.SQLite3.Bindings.Types (CError(..))
import qualified Data.Text as T
import           Foreign.C.Types (CInt(..))
import           Foreign.Ptr (Ptr, nullPtr)
import           System.Environment (getExecutablePath)


-- | No need for exact type signature, we call it as
-- > sqlite3_appendvfs_init(0,0,0);
-- only, just like the sqlite3 binary (`shell.c.in`) does.
foreign import ccall "sqlite3_appendvfs_init"
  sqlite3_appendvfs_init :: Ptr () -> Ptr () -> Ptr () -> IO CError


main :: IO ()
main = do
  -- Register the "appendvfs" extension. See:
  --     https://www.sqlite.org/loadext.html#persistent_loadable_extensions
  -- We do NOT check the returned `CError` code with `fromFFI` here because
  -- `decodeError` in `direct-sqlite`'s `Database.SQLite3.Bindings.Types`
  -- is partial and does not currently handle extended result values like
  -- `SQLITE_OK_LOAD_PERMANENTLY`; it will `error` with `decodeError 256`.
  -- https://www.sqlite.org/c3ref/extended_result_codes.html documents that
  -- extended result codes are off by default, but extensions like
  -- `appendvfs.c` do not currently follow that rule.
  CError result <- sqlite3_appendvfs_init nullPtr nullPtr nullPtr
  when (result /= 256) $ do -- 256 == SQLITE_OK_LOAD_PERMANENTLY
    error $ "sqlite3_appendvfs_init failed with code " ++ show result

  exePath <- getExecutablePath
  -- Open the DB appended to the executable.
  -- Requires that you appended a DB first using e.g.:
  --     sqlite3 --append path/to/exe \
  --       "CREATE TABLE testtable (field1 TEXT);
  --        INSERT INTO testtable (field1) VALUES ('hello'), ('world');"
  -- Open options:
  --   * `apndvfs` - needs sqlite's `ext/misc/appendvfs.c` linked in
  --   * `ro`      - read-only-mode is important because you usually cannot modify
  --                 the contents of a running executable (certainly not on Linux).
  conn <- open ("file:" ++ exePath ++ "?vfs=apndvfs&mode=ro")

  r <- query_ conn "SELECT * from testtable" :: IO [Only T.Text]
  putStrLn "Database contents:"
  for_ r $ \(Only text) -> print text

  close conn
