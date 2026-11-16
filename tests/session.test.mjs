import { test } from 'node:test'
import assert from 'node:assert/strict'
import { makeRequest } from './mocks/next-server.mjs'
import { middleware as before } from '../fixes/01-auth-session/before/middleware.ts'
import { middleware as after } from '../fixes/01-auth-session/after/middleware.ts'

const maya = { id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', email: 'maya@example.test' }
const expiredCookie = () => [{ name: 'sb-auth-token', value: JSON.stringify({ access_token: 'old-access', refresh_token: 'valid-refresh', expired: true, user: maya }) }]
const forgedCookie = () => [{ name: 'sb-auth-token', value: JSON.stringify({ access_token: 'forged', refresh_token: 'none', user: { id: 'someone-else' } }) }]
const refreshedCookieOn = (res) => res.cookies.get('sb-auth-token')

test('BEFORE: refreshed tokens never reach the browser (logged out after ~1h)', async () => {
  const res = await before(makeRequest('/dashboard', expiredCookie()))
  assert.equal(res.kind, 'next')
  assert.equal(refreshedCookieOn(res), undefined)
})
test('BEFORE: a forged cookie gets past the /dashboard gate', async () => {
  const res = await before(makeRequest('/dashboard', forgedCookie()))
  assert.equal(res.kind, 'next')
})
test('AFTER: refreshed tokens are set on the response', async () => {
  const res = await after(makeRequest('/dashboard', expiredCookie()))
  assert.equal(res.kind, 'next')
  const c = refreshedCookieOn(res)
  assert.ok(c, 'expected Set-Cookie for sb-auth-token')
  assert.equal(JSON.parse(c.value).access_token, 'valid-access-2')
})
test('AFTER: a forged cookie is redirected to /login', async () => {
  const res = await after(makeRequest('/dashboard', forgedCookie()))
  assert.equal(res.kind, 'redirect')
  assert.equal(res.location, '/login')
})
