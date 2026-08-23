
## Testing

Run: `npm test` (Vitest). Test files live next to the source they test:
`src/scripts/blog.ts` → `src/scripts/blog.test.ts` — **except** anything
under `src/pages/`, which Astro treats as a route: a test file placed there
breaks `npm run build` silently. Tests for `src/pages/` files go in
`src/test/pages/` instead, mirroring the relative path (e.g.
`src/pages/llms.txt.ts` → `src/test/pages/llms.txt.test.ts`). Full context in
`TESTING.md`.

Only covers `src/` (TypeScript/Astro). `server/` (PHP) has no test runner yet.

Expectations:
- 100% coverage is the goal — tests make changes safe to make quickly.
- New function → write a corresponding test.
- Bug fix → write a regression test that would have caught it.
- New error handling → write a test that triggers the error path.
- New conditional (if/else, switch) → test both branches.
- Never commit code that makes an existing test fail.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
