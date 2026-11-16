# Next.js + Supabase bug-fix case study (sample, fictional app)

[![case-study-tests](https://github.com/djonovic/nextjs-supabase-bugfix-case-study/actions/workflows/ci.yml/badge.svg)](https://github.com/djonovic/nextjs-supabase-bugfix-case-study/actions/workflows/ci.yml)
**Live write-up:** https://djonovic.github.io/nextjs-supabase-bugfix-case-study/

![Case study overview: 3 bugs, before and after](screenshots/cover-1600x1200.png)

> **In 10 seconds:** three bugs that show up in real Next.js + Supabase apps:
> users logged out after an hour, an RLS policy that leaks every team's rows,
> and a dashboard query doing a full table scan. Each one is reproduced,
> fixed, and proven by a test that runs on every push.

**This is a sample.** "Tasklane" is a fictional team-tasks app made for this
case study, and all data (Maya, Leo, Maple Studio, Cedar Labs) is made up.
No client or real company is involved.

| # | Bug | Before | After | Proof |
| --- | --- | --- | --- | --- |
| [01](fixes/01-auth-session/) | Auth/session: refreshed cookies dropped in middleware; `getSession()` trusted on the server | logged out after ~1 h; forged cookie reaches `/dashboard` | cookies refreshed; `getUser()` gate redirects to `/login` | `tests/session.test.mjs` (simulated Supabase client) |
| [02](fixes/02-rls-leak/) | RLS policy `EXISTS` not tied to the row's workspace | Maya sees **500,002** other-workspace rows | **0** | Postgres RLS as `authenticated` |
| [03](fixes/03-slow-query/) | Missing index for "My open tasks" | Seq Scan, 500,166 rows discarded, 59 ms | Index Scan, 0.14 ms | `EXPLAIN (ANALYZE, BUFFERS)` |

## Repo layout

| Path | What it is |
| --- | --- |
| `fixes/01-auth-session/{before,after}/` | `middleware.ts` and `app/dashboard/page.tsx`, broken and fixed |
| `fixes/02-rls-leak/{before,after}/policy.sql` | The leaking and the corrected RLS policy |
| `fixes/03-slow-query/` | The query, the index migration, `EXPLAIN` before/after |
| `supabase/migrations/` | `0001` schema → `0002` broken policy → `0003` fixed policy → `0004` index |
| `supabase/seed.sql` | Fictional users + ~500k synthetic tasks |
| `tests/run.sh` | Reproduces each bug, applies the fix, asserts the result |
| `docs/` | The GitHub Pages write-up |

## Run it

Needs PostgreSQL 14+ with `psql`, and Node 22.18+ (runs the `.ts` middleware
directly). No hosted Supabase project needed: `auth.uid()` and the
`authenticated` role are emulated the same way Supabase sets them.

```bash
createdb tasklane
DATABASE_URL=postgres://postgres:postgres@localhost:5432/tasklane bash tests/run.sh
```

Expected tail:
```
BEFORE  Maya sees own=302  other workspaces=500002
AFTER   Maya sees own=302  other workspaces=0
BEFORE  Seq Scan on tasks  59.230 ms
AFTER   Index Scan using tasks_open_by_assignee_idx  0.143 ms
ALL CHECKS PASSED
```

## How I'd work on your app

The same loop: reproduce the bug with a failing check, fix it with the smallest
change, and leave the check in CI so it can't come back.

Built by [Pasko Djonovic](https://www.upwork.com/freelancers/paskodjonovic) —
Next.js + Supabase developer (RLS, auth, performance). Related:
[Supabase security audit sample](https://djonovic.github.io/supabase-security-audit-demo/).
