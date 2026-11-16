#!/usr/bin/env bash
# Reproduce all three bugs, apply the fixes, and prove each one.
# Usage: DATABASE_URL=postgres://postgres:postgres@localhost:5432/tasklane bash tests/run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DATABASE_URL:?Set DATABASE_URL}"
export PGSSLMODE="${PGSSLMODE:-disable}"
export PGOPTIONS="${PGOPTIONS:--c client_min_messages=warning}"
OUT="$ROOT/tests/output"; mkdir -p "$OUT"
MAYA='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
MAPLE='11111111-1111-4111-8111-111111111111'
psqlx() { psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q "$@"; }
# Run SQL as Maya through RLS, exactly like a PostgREST request with her JWT.
as_maya() {
  printf "BEGIN;\nSET LOCAL ROLE authenticated;\nSET LOCAL request.jwt.claim.sub = '%s';\n%s;\nCOMMIT;\n" "$MAYA" "$1" \
    | psqlx -At -f -
}
fail() { echo "FAIL: $*"; exit 1; }

echo "== Reset + schema + broken RLS policy + seed (~500k fictional tasks)"
psqlx -c "DROP SCHEMA IF EXISTS auth CASCADE; DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;"
psqlx -f "$ROOT/supabase/migrations/0001_schema.sql"
psqlx -f "$ROOT/supabase/migrations/0002_rls_broken.sql"
psqlx -f "$ROOT/supabase/seed.sql"

echo; echo "== Fix 02 — RLS leak"
OWN_B=$(as_maya "SELECT count(*) FROM public.tasks WHERE workspace_id = '$MAPLE';")
LEAK_B=$(as_maya "SELECT count(*) FROM public.tasks WHERE workspace_id <> '$MAPLE';")
SAMPLE=$(as_maya "SELECT title FROM public.tasks WHERE title LIKE 'Confidential%' ORDER BY title;" | paste -sd'|' -)
echo "BEFORE  Maya sees own=$OWN_B  other workspaces=$LEAK_B  e.g. [$SAMPLE]"
[ "$LEAK_B" -gt 0 ] || fail "expected the broken policy to leak rows"
psqlx -f "$ROOT/supabase/migrations/0003_rls_fixed.sql"
OWN_A=$(as_maya "SELECT count(*) FROM public.tasks WHERE workspace_id = '$MAPLE';")
LEAK_A=$(as_maya "SELECT count(*) FROM public.tasks WHERE workspace_id <> '$MAPLE';")
echo "AFTER   Maya sees own=$OWN_A  other workspaces=$LEAK_A"
[ "$LEAK_A" -eq 0 ] || fail "fixed policy still leaks $LEAK_A rows"
[ "$OWN_A" -eq "$OWN_B" ] || fail "fixed policy hides Maya's own rows ($OWN_A vs $OWN_B)"

echo; echo "== Fix 03 — slow dashboard query (EXPLAIN ANALYZE as Maya, RLS on)"
Q="$(grep -v '^--' "$ROOT/fixes/03-slow-query/dashboard-query.sql" | sed 's/;\s*$//')"
as_maya "EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) $Q" > "$OUT/explain-before.txt"
psqlx -f "$ROOT/supabase/migrations/0004_tasks_dashboard_index.sql"
as_maya "EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) $Q" > "$OUT/explain-after.txt"
T_B=$(grep -oP 'Execution Time: \K[0-9.]+' "$OUT/explain-before.txt")
T_A=$(grep -oP 'Execution Time: \K[0-9.]+' "$OUT/explain-after.txt")
echo "BEFORE  $(grep -oE 'Seq Scan on tasks|Index Scan[^(]*' "$OUT/explain-before.txt" | head -1)  ${T_B} ms"
echo "AFTER   $(grep -oE 'Index Scan using [a-z_]+|Seq Scan on tasks' "$OUT/explain-after.txt" | head -1)  ${T_A} ms"
grep -q 'Seq Scan on tasks' "$OUT/explain-before.txt" || fail "expected a Seq Scan before the index"
grep -q 'tasks_open_by_assignee_idx' "$OUT/explain-after.txt" || fail "expected the new index to be used"
ROWS=$(as_maya "SELECT count(*) FROM ($Q) q;")
[ "$ROWS" -gt 0 ] || fail "dashboard query returned no rows"

echo; echo "== Fix 01 — auth/session middleware (Node, simulated @supabase/ssr client)"
node --import "$ROOT/tests/register.mjs" "$ROOT/tests/session.test.mjs"

printf '{"rls_leak_before":%s,"rls_leak_after":%s,"own_rows":%s,"query_ms_before":%s,"query_ms_after":%s}\n' \
  "$LEAK_B" "$LEAK_A" "$OWN_A" "$T_B" "$T_A" > "$OUT/results.json"
echo; echo "ALL CHECKS PASSED  $(cat "$OUT/results.json")"
