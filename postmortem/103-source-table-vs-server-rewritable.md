# 103 — source-table conflated with server-rewritable

## Symptom

A displayer registered with `clutch-register-column-displayer` silently did nothing
when the triggering query carried its own `LIMIT` or `OFFSET` clause.  The same
column in the same table without `LIMIT` worked.  Similarly, staging an UPDATE on a
single-table `LIMIT 10` result failed with *"source table cannot be detected (multi-
table or derived query)"* even though the table was unambiguous.

## Root cause

`clutch-result.el` conflated two independent concepts:

- **Is this result safe to rewrite?** — server-side sort, filter, and pagination all
  require the query to have no own LIMIT/OFFSET.  Correct: `server-rewritable` is
  false for user-supplied LIMIT queries.
- **Which table did this result come from?** — useful for displayers, the header
  line, FK info, agent context, and (together with row identity) mutations.

The code at `clutch-result.el:297` only set `source-table` when `server-rewritable`
was non-nil:

```elisp
(source-table (or (plist-get result-context :source-table)
                  (and server-rewritable             ; <- LIMIT forced nil here
                       (plist-get row-identity-prep :table))))
```

Because `clutch--server-rewritable-result-p` deliberately returns nil for queries
with a top-level LIMIT/OFFSET, any user-supplied `LIMIT` silently cleared the source
table, even for a perfectly unambiguous single-table SELECT.

The SQL parser (`clutch-db-sql-source-table`) was never the problem — it returns the
correct table name for both `SELECT id FROM t` and `SELECT id FROM t LIMIT 10`.

## Fix

Added a `simple-only` parser fallback as the last resort in the `or` chain
(`clutch-result.el:297`):

```elisp
(source-table (or (plist-get result-context :source-table)
                  (and server-rewritable
                       (plist-get row-identity-prep :table))
                  (clutch-db-sql-source-table sql t)))   ; simple-only
```

`simple-only t` returns nil for joins, comma-joins, derived tables, CTEs, and
UNION/INTERSECT/EXCEPT — genuinely ambiguous, correctly left nil.  Single-table
queries with LIMIT/OFFSET now record the table just as their non-LIMIT counterparts
do.

Rewrite and mutation safety are unchanged: `server-rewritable` / `server-pageable`
remain false for LIMIT queries; mutations require both source-table *and* row
identity (`clutch-result.el:2153-2154`).

## Lesson

Source-table identity and result rewritability answer different questions.  The
rewrite gate (`server-rewritable`) is intentionally conservative; keying an unrelated
concern off it creates surprising silent failures wherever the table name is needed
for display, not mutations.  Keep the two separate at the point of recording.
