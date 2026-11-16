// Simulated @supabase/ssr server client. It mimics the two behaviours that
// matter here (not the real library):
//  - an expired access token is refreshed and the new cookies are handed to
//    cookies.setAll() — as the real client does;
//  - getSession() decodes the cookie without verification, getUser() asks the
//    Auth server and rejects tokens it did not issue.
export const AUTH_SERVER = { issued: new Set(['valid-access']), refresh: { 'valid-refresh': 'valid-access-2' } }
export function createServerClient(_url, _key, { cookies }) {
  function read() {
    const c = Object.fromEntries(cookies.getAll().map((x) => [x.name, x.value]))
    return c['sb-auth-token'] ? JSON.parse(c['sb-auth-token']) : null
  }
  function maybeRefresh(tok) {
    if (tok && tok.expired && AUTH_SERVER.refresh[tok.refresh_token]) {
      const access = AUTH_SERVER.refresh[tok.refresh_token]
      AUTH_SERVER.issued.add(access)
      const next = { access_token: access, refresh_token: 'valid-refresh-2', user: tok.user }
      cookies.setAll([{ name: 'sb-auth-token', value: JSON.stringify(next), options: { path: '/', httpOnly: false, sameSite: 'lax' } }])
      return next
    }
    return tok
  }
  return {
    auth: {
      async getSession() {
        const tok = maybeRefresh(read())
        return { data: { session: tok ? { user: tok.user, access_token: tok.access_token } : null } }
      },
      async getUser() {
        const tok = maybeRefresh(read())
        const ok = tok && AUTH_SERVER.issued.has(tok.access_token)
        return { data: { user: ok ? tok.user : null } }
      },
    },
  }
}
