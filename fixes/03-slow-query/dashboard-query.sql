-- "My open tasks" on the Tasklane dashboard, as PostgREST runs it for
--   supabase.from('tasks').select('id,title,status,due_at')
--     .eq('workspace_id', ws).eq('assignee_id', uid).neq('status', 'done')
--     .order('created_at', { ascending: false }).limit(50)
SELECT id, title, status, due_at
FROM public.tasks
WHERE workspace_id = '11111111-1111-4111-8111-111111111111'
  AND assignee_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  AND status <> 'done'
ORDER BY created_at DESC
LIMIT 50;
