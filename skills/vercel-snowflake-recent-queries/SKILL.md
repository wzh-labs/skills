---
name: vercel-snowflake-recent-queries
description: Show the N most recently executed queries in Snowflake. Use when the user asks to "show recent Snowflake queries", "what queries ran in Snowflake", "show last N queries", "check Snowflake query history", or similar. Supports filtering by user, warehouse, status, and query type.
---

# Show recent Snowflake queries

Goal: retrieve and display the N most recently executed queries from Snowflake query history in a readable, signal-dense format. Useful for debugging, auditing, and understanding what's running against your warehouse.

## Inputs

Required: none (all have defaults)

Optional:
- `N` — number of queries to show (default 20, max 200)
- `user` — case-insensitive substring filter on USER_NAME (e.g. `thomas` matches `THOMAS.WANG@VERCEL.COM`)

## Source selection

Prefer `INFORMATION_SCHEMA.QUERY_HISTORY()` — it's real-time (no latency), available to any role that has USAGE on the database, and covers the last 7 days. Fall back to `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` only when the user explicitly asks for history older than 7 days or needs account-wide data (requires ACCOUNTADMIN or MONITOR privilege and has up to 45-minute latency; note this in output).

## Method

### 1. Build and run the query

Use `snow sql` to execute against Snowflake. Always use the `vercel` connection:

```bash
snow sql -q "<query>" --connection vercel --format json
```

**Primary query (INFORMATION_SCHEMA, last 7 days):**

```sql
SELECT
  QUERY_ID,
  QUERY_TEXT,
  USER_NAME,
  ROLE_NAME,
  WAREHOUSE_NAME,
  EXECUTION_STATUS,
  QUERY_TYPE,
  START_TIME,
  TOTAL_ELAPSED_TIME / 1000.0        AS duration_sec,
  ROWS_PRODUCED,
  BYTES_SCANNED / 1024.0 / 1024.0   AS mb_scanned,
  ERROR_CODE,
  ERROR_MESSAGE
FROM TABLE(DWH_PROD.INFORMATION_SCHEMA.QUERY_HISTORY(
  RESULT_LIMIT => <N>
))
WHERE CONTAINS(UPPER(USER_NAME), UPPER('<user>'))   -- omit this line when no user filter provided
ORDER BY START_TIME DESC
LIMIT <N>;
```

Notes on this query:
- Must use a fully qualified database prefix (`DWH_PROD.INFORMATION_SCHEMA`) — bare `INFORMATION_SCHEMA.QUERY_HISTORY` fails with a compilation error.
- Do NOT pass `END_TIME_RANGE_START` — even `DATEADD('day', -7, ...)` trips Snowflake's boundary guard ("Cannot retrieve data from more than 7 days ago"). Omit it and rely solely on `RESULT_LIMIT`.
- `ROWS_SCANNED` does not exist in this instance's view — use `BYTES_SCANNED` only.
- When a `user` filter is provided, add `WHERE CONTAINS(UPPER(USER_NAME), UPPER('<user>'))` after the `TABLE(...)` clause. Because the function returns recent rows before filtering, always use `RESULT_LIMIT => 10000` (the maximum) so the post-filter still yields N rows on busy accounts. Omit the WHERE clause entirely when no user filter is given.

**Fallback query (ACCOUNT_USAGE, >7 days):**

```sql
SELECT
  QUERY_ID,
  QUERY_TEXT,
  USER_NAME,
  ROLE_NAME,
  WAREHOUSE_NAME,
  EXECUTION_STATUS,
  QUERY_TYPE,
  START_TIME,
  TOTAL_ELAPSED_TIME / 1000.0        AS duration_sec,
  ROWS_PRODUCED,
  BYTES_SCANNED / 1024.0 / 1024.0   AS mb_scanned,
  ERROR_CODE,
  ERROR_MESSAGE
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD('day', -90, CURRENT_TIMESTAMP())
  AND CONTAINS(UPPER(USER_NAME), UPPER('<user>'))   -- omit this line when no user filter provided
ORDER BY START_TIME DESC
LIMIT <N>;
```

Note in output if ACCOUNT_USAGE was used and its ~45-minute latency caveat.

### 2. Handle errors

- **Authentication failure:** print the `snow` error verbatim and stop. Do not retry with different credentials.
- **Insufficient privileges:** suggest `GRANT MONITOR EXECUTION ON ACCOUNT TO ROLE <role>` or switching to a role with `ACCOUNTADMIN`. If on INFORMATION_SCHEMA and USAGE is missing, suggest `GRANT USAGE ON DATABASE <db> TO ROLE <role>`.
- **No rows returned:** say "No queries matched the filters in the given time window" — do not fabricate results.
- **`snow` CLI not found:** tell the user to install it (`pip install snowflake-cli-labs` or `brew install snowflake-cli`) and configure a connection with `snow connection add`.

### 3. Truncate long query text

Truncate QUERY_TEXT to 120 characters in the table view. Show the full text when displaying a single query or when the user asks to expand a specific row.

## Output format

```
## Recent Snowflake Queries  (N=<n> · user: <user filter or "all"> · source: INFORMATION_SCHEMA · as of <timestamp>)

| # | Started (UTC)        | Duration | Status  | Type   | User         | Warehouse | Rows out | Query (truncated)                          |
|---|----------------------|----------|---------|--------|--------------|-----------|----------|--------------------------------------------|
| 1 | 2026-04-29 14:32:01  | 0.42s    | SUCCESS | SELECT | thomas.wang  | COMPUTE_WH| 142      | SELECT * FROM orders WHERE created_at >... |
| 2 | 2026-04-29 14:31:58  | 12.3s    | SUCCESS | INSERT | dbt_prod     | TRANSFORM  | 0        | INSERT INTO fct_revenue SELECT ...         |
| 3 | 2026-04-29 14:28:44  | 0.08s    | FAILED  | SELECT | thomas.wang  | COMPUTE_WH| —        | SELECT user_id FROM sessions LIMIT 10      |
...

**Failed queries:** <count>  ·  **Slowest:** <duration>s (<query_id>)  ·  **Total rows produced:** <sum>

[note if ACCOUNT_USAGE used: Data may lag up to 45 minutes.]
```

Rules:
- Right-align numeric columns (duration, rows, MB).
- Show `—` for NULL/0 values in rows_produced when status is FAILED.
- Flag failed queries with a `FAILED` status — do not silently skip them.
- Show the summary line (failed count, slowest, total rows) only when N ≥ 5.
- Show query_id in the summary line so the user can look it up in Snowflake UI.
- **RUNNING queries have negative `TOTAL_ELAPSED_TIME`** — Snowflake sets this relative to epoch while a query is in flight. Show `—` for duration on any row where `EXECUTION_STATUS = 'RUNNING'` or `duration_sec < 0`. Exclude these rows from the "slowest" summary stat.

## Style rules

- Never expose credentials, passwords, or private keys from `snow` output.
- Don't run any query other than the history fetch — do not execute, explain, or analyze the retrieved query texts.
- Be concise — this is a lookup tool, not a report. Output the table, summary, and any errors. Nothing else unless the user asks follow-up questions.
- Always use `--connection vercel`. Never prompt the user to specify a connection name.
