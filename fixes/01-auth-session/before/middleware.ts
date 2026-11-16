// BEFORE — Tasklane middleware.ts (fictional app). Two bugs:
//  1) refreshed auth cookies are never written to the response, so the browser
//     keeps the old tokens and users get logged out ~1 hour after login;
//  2) getSession() only decodes the cookie; it does not verify it with
//     Supabase Auth, so a forged/expired cookie passes the auth gate.
import { NextResponse, type NextRequest } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  const response = NextResponse.next()

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          // BUG 1: only the request is updated; the browser never sees the new tokens.
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        },
      },
    },
  )

  // BUG 2: trusts the cookie contents without asking Supabase Auth.
  const { data: { session } } = await supabase.auth.getSession()

  if (!session && request.nextUrl.pathname.startsWith('/dashboard')) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }
  return response
}

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'] }
