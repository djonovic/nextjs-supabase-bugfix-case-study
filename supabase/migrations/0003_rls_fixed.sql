-- AFTER (fix 02): correlate the membership check with the row's workspace.
-- (SELECT auth.uid()) is evaluated once per statement instead of per row,
-- as recommended in Supabase's RLS performance guide.
BEGIN;
DROP POLICY IF EXISTS "members can read tasks" ON public.tasks;

CREATE POLICY "members can read tasks" ON public.tasks
  FOR SELECT TO authenticated
  USING (
    workspace_id IN (
      SELECT wm.workspace_id FROM public.workspace_members wm
      WHERE wm.user_id = (SELECT auth.uid())
    )
  );

-- Supports the membership lookup inside the policy.
CREATE INDEX IF NOT EXISTS workspace_members_user_id_idx
  ON public.workspace_members (user_id, workspace_id);
COMMIT;
