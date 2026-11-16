-- BEFORE (fix 02): the policy as it shipped. RLS is "enabled" in the
-- dashboard, but the EXISTS subquery is not tied to the row being read.
BEGIN;
DROP POLICY IF EXISTS "members can read tasks" ON public.tasks;

CREATE POLICY "members can read tasks" ON public.tasks
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.user_id = auth.uid()
      -- BUG: missing  AND wm.workspace_id = tasks.workspace_id
    )
  );
COMMIT;
