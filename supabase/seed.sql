-- Fictional seed data. Two named users for the leak test, plus ~500k
-- synthetic tasks across 2,000 workspaces so the slow query is realistic.
BEGIN;
DO $$ BEGIN PERFORM setseed(0.42); END $$;

INSERT INTO auth.users (id, email) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'maya@example.test'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'leo@example.test');

INSERT INTO public.workspaces (id, name) VALUES
  ('11111111-1111-4111-8111-111111111111', 'Maple Studio (fictional)'),
  ('22222222-2222-4222-8222-222222222222', 'Cedar Labs (fictional)');

INSERT INTO public.workspace_members (workspace_id, user_id, role) VALUES
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'owner'),
  ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'owner');

INSERT INTO public.tasks (workspace_id, assignee_id, title, status) VALUES
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Draft Q1 roadmap', 'doing'),
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Review landing page copy', 'todo'),
  ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Confidential: pricing change for enterprise plan', 'todo'),
  ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'Confidential: hiring plan', 'doing');

-- Synthetic load: 2,000 workspaces x 250 tasks, 200 synthetic users.
INSERT INTO auth.users (id, email)
SELECT gen_random_uuid(), 'user' || g || '@example.test' FROM generate_series(1, 200) g;

INSERT INTO public.workspaces (name)
SELECT 'Synthetic workspace ' || g FROM generate_series(1, 2000) g;

WITH u AS (SELECT array_agg(id) AS ids FROM auth.users WHERE email LIKE 'user%'),
     w AS (SELECT id, row_number() OVER () AS rn FROM public.workspaces WHERE name LIKE 'Synthetic%')
INSERT INTO public.tasks (workspace_id, assignee_id, title, status, created_at)
SELECT w.id,
       u.ids[1 + floor(random() * 200)::int],
       'Synthetic task ' || g,
       (ARRAY['todo', 'doing', 'done', 'done'])[1 + floor(random() * 4)::int],
       now() - (random() * interval '365 days')
FROM w, u, generate_series(1, 250) g;

-- Maya also gets a realistic backlog in her own workspace.
INSERT INTO public.tasks (workspace_id, assignee_id, title, status, created_at)
SELECT '11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
       'Backlog item ' || g,
       (ARRAY['todo', 'doing', 'done', 'done'])[1 + floor(random() * 4)::int],
       now() - (random() * interval '365 days')
FROM generate_series(1, 300) g;
COMMIT;
ANALYZE;
