// Minimal stand-in for next/server: just enough cookie + redirect behaviour.
class Cookies {
  constructor(init = []) { this.map = new Map(init.map((c) => [c.name, c])) }
  getAll() { return [...this.map.values()] }
  get(name) { return this.map.get(name) }
  set(name, value, options = {}) { this.map.set(name, { ...options, name, value }) }
}
export class NextResponse {
  constructor(kind, location) { this.kind = kind; this.location = location; this.cookies = new Cookies() }
  static next() { return new NextResponse('next') }
  static redirect(url) { return new NextResponse('redirect', url.pathname) }
}
export function makeRequest(pathname, cookies) {
  return {
    cookies: new Cookies(cookies),
    nextUrl: { pathname, clone() { return { pathname: this.pathname } } },
  }
}
