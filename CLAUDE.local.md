@AGENTS.md

# Running tests

Dependencies (`mysql`, `pg`, `peg`) live in the user's straight.el build tree and must be
added to the Emacs load path via `CLUTCH_EXTRA_LOAD_PATH`.

Set the env var (adjust the straight path if different):

```
export CLUTCH_EXTRA_LOAD_PATH=\
~/dev/dotemacsng/straight/build/mysql:\
~/dev/dotemacsng/straight/build/pg:\
~/dev/dotemacsng/straight/build/peg:\
~/dev/dotemacsng/straight/build/mongodb:\
~/dev/dotemacsng/straight/build/redis
```

Run the non-live CI suite (skips `package-lint`, which requires a live MELPA connection):

```
./test/run-ci.sh main db byte-compile checkdoc
```

Expected result: 0 unexpected failures; ~10 live-DB tests skipped in the main suite,
~54 skipped in the db suite (MySQL/PostgreSQL/MongoDB/Redis/Oracle/ClickHouse/MSSQL
live tests).

## Notes

- `package-lint` (the `all` target) fails locally because batch Emacs has no cached MELPA
  index. It works in CI where `package-refresh-contents` is called. Skip it locally.
- The 10 / 40 skipped tests are live MySQL / PostgreSQL / Oracle integration tests that
  require running containers. Use `./test/run-native-live-tests.sh` for those.
