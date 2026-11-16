Before: no migration — `public.tasks` only has its primary key, so the dashboard
query (`../dashboard-query.sql`) scans every row. Plan: [`explain.txt`](explain.txt).
