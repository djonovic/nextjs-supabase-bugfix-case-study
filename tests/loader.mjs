const MOCKS = {
  'next/server': new URL('./mocks/next-server.mjs', import.meta.url).href,
  '@supabase/ssr': new URL('./mocks/supabase-ssr.mjs', import.meta.url).href,
}
export async function resolve(specifier, context, next) {
  if (MOCKS[specifier]) return { url: MOCKS[specifier], shortCircuit: true }
  return next(specifier, context)
}
