# Fix 02 — RLS policy leaked every workspace's tasks

**Sample case study, fictional app (Tasklane), fictional data.**

## Symptom
Row Level Security showed as *enabled* on `tasks`, yet Maya (member of
*Maple Studio* only) could load tasks from every other workspace, including
Cedar Labs' "Confidential: pricing change for enterprise plan".

## Root cause ([before](before/policy.sql))
```sql
USING (EXISTS (SELECT 1 FROM workspace_members wm
               WHERE wm.user_id = auth.uid()))   -- not tied to tasks.workspace_id
```
The subquery only asks "is this user a member of *any* workspace?". It is true
for every logged-in user, so every row passes.

## Fix ([after](after/policy.sql))
```sql
USING (workspace_id IN (SELECT wm.workspace_id FROM workspace_members wm
                        WHERE wm.user_id = (SELECT auth.uid())))
```
Plus an index on `workspace_members (user_id, workspace_id)` for the lookup.
`(SELECT auth.uid())` is evaluated once per query instead of once per row.

## Proof (`tests/run.sh`, real PostgreSQL RLS as role `authenticated`)

| Maya's query | Before | After |
| --- | --- | --- |
| Rows from her own workspace | 302 | 302 |
| Rows from other workspaces | **500,002** | **0** |
