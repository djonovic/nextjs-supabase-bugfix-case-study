# Fix 01 — Users logged out after ~1 hour, and a spoofable auth check

**Sample case study, fictional app (Tasklane).**

## Symptom
Users of the dashboard were signed out roughly an hour after logging in, often
mid-task. Support saw "Invalid Refresh Token: Already Used" in the Auth logs.

## Root cause
Two mistakes in `middleware.ts` ([before](before/middleware.ts)):

1. **Refreshed cookies were thrown away.** `@supabase/ssr` refreshes an expired
   access token and hands the new cookies to `setAll()`. The middleware wrote
   them to the *request* only and returned a response created earlier, so the
   browser never received the new tokens. Once the access token expired (1 h by
   default) the browser kept sending the old refresh token, which Supabase
   rejects after rotation, and the user was logged out.
2. **`getSession()` on the server.** It reads the session from the cookie
   without verifying it with Supabase Auth, so a forged cookie passes the
   `/dashboard` gate. The dashboard page used `session.user.id` the same way
   ([before](before/dashboard-page.tsx)).

## Fix ([after](after/middleware.ts))
- Re-create the response inside `setAll()` and copy every refreshed cookie
  onto it (the pattern from Supabase's Next.js SSR guide); keep those cookies
  on redirects too.
- Gate routes and read the user id with `supabase.auth.getUser()`, which
  validates the token with Supabase Auth ([after](after/dashboard-page.tsx)).

## Proof
`tests/session.test.mjs` runs the real before/after `middleware.ts` under
Node with a **simulated** Supabase client (it mimics token refresh and
cookie-vs-server verification; it is not the real library):

| Check | Before | After |
| --- | --- | --- |
| Expired token → refreshed cookie on the response | missing | `Set-Cookie: sb-auth-token` |
| Forged cookie → `/dashboard` | allowed | redirected to `/login` |
