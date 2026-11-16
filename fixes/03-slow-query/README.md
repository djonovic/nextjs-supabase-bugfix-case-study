# Fix 03 — Slow "My open tasks" dashboard query

**Sample case study, fictional app (Tasklane), ~500k fictional rows.**

## Symptom
The dashboard's "My open tasks" list got slower as the table grew. Every page
load ran this query ([dashboard-query.sql](dashboard-query.sql)):

```ts
supabase.from('tasks').select('id,title,status,due_at')
  .eq('workspace_id', ws).eq('assignee_id', uid).neq('status', 'done')
  .order('created_at', { ascending: false }).limit(50)
```

## Root cause ([before/explain.txt](before/explain.txt))
No index matches the filter + sort, so Postgres reads the whole table and sorts:
`Seq Scan on tasks … Rows Removed by Filter: 500166`, `shared hit=6243` buffers.

## Fix ([after/0004_tasks_dashboard_index.sql](after/0004_tasks_dashboard_index.sql))
```sql
CREATE INDEX tasks_open_by_assignee_idx
  ON public.tasks (workspace_id, assignee_id, created_at DESC)
  WHERE status <> 'done';
```
Equality columns first, then the sort column, partial on open tasks, so
Postgres walks the index in order and stops after 50 rows (use
`CREATE INDEX CONCURRENTLY` on a live database).

## Proof (`EXPLAIN (ANALYZE, BUFFERS)`, as Maya with RLS on)

| | Before | After |
| --- | --- | --- |
| Plan | Seq Scan + top-N sort | Index Scan using `tasks_open_by_assignee_idx` |
| Rows read and discarded | 500,166 | 0 |
| Buffers | 6,243 | 41 |
| Execution time | 59.2 ms | 0.14 ms |

Measured on PostgreSQL 17.5 on a dev machine; CI re-runs it on Postgres 16 and
uploads the plans as an artifact. Absolute times vary by machine; the plan
change is what matters.
