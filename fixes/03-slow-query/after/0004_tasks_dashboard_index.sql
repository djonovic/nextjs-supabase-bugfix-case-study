-- AFTER (fix 03): composite partial index matching the dashboard query
--   WHERE workspace_id = ? AND assignee_id = ? AND status <> 'done'
--   ORDER BY created_at DESC LIMIT 50
-- In production use CREATE INDEX CONCURRENTLY (outside a transaction).
CREATE INDEX IF NOT EXISTS tasks_open_by_assignee_idx
  ON public.tasks (workspace_id, assignee_id, created_at DESC)
  WHERE status <> 'done';
ANALYZE public.tasks;
