// npm run verify: tests y build en secuencia; para en el primer fallo y sale
// con su codigo. Sin dependencias: solo child_process. `shell: true` porque en
// Windows npm es npm.cmd y spawnSync no lo resuelve sin shell.
import { spawnSync } from 'node:child_process';

const steps = [
  ['npm', ['test']],
  ['npm', ['run', 'build']],
];

for (const [cmd, args] of steps) {
  const label = `${cmd} ${args.join(' ')}`;
  console.log(`\n[verify] ${label}`);
  const res = spawnSync(cmd, args, { stdio: 'inherit', shell: true });
  const code = res.status ?? 1;
  if (res.error || code !== 0) {
    console.error(`[verify] FALLO en "${label}" (codigo ${code})`);
    process.exit(code || 1);
  }
}
console.log('\n[verify] OK: tests y build en verde');
