// Wires the FACTORY_ALLOWED_EMAILS sign-in allowlist into upstream's entry. Fails the
// build if upstream's WorkOS line moves, so a version bump cannot silently drop the lock.
import { readFileSync, writeFileSync } from 'node:fs';

const path = 'src/mastra/index.ts';
const needle = '  auth = new MastraAuthWorkos({ fetchMemberships: true });';
let src = readFileSync(path, 'utf8');
if (!src.includes(needle)) throw new Error(`patch-entry: upstream WorkOS line not found in ${path}`);
src = src.replace(
  needle,
  '  const workos = new MastraAuthWorkos({ fetchMemberships: true });\n' +
    '  restrictWorkosAuth(workos, process.env.FACTORY_ALLOWED_EMAILS);\n' +
    '  auth = workos;',
);
src = `import { restrictWorkosAuth } from './workos-access.js';\n${src}`;
writeFileSync(path, src);
