// Maps the two framework imports in middleware.ts to small test doubles, so
// the real before/after files run under plain Node (24+ strips TS types).
import { register } from 'node:module'
register('./loader.mjs', import.meta.url)
