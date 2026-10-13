# WP-<n>: <title>
type: impl-complex | impl-simple | tests | docs | foundation
complexity: S | M | L    risk: L | M | H    wave: <k>
agent: <agent>   model: <haiku|sonnet|opus>   effort: <low|medium|high>   isolation: worktree | none
depends_on: [WP-x]

## Objective
<one paragraph: what this WP delivers and why>

## Owned files (only these may be edited/created)
- path/to/file.ext — create | modify

## Reads (read-only context)
- path/to/contract.ext

## Interfaces / contracts
- Provides: <exact signature/types>
- Consumes: <exact signature/types, from spec §7 or WP-0>

## Acceptance criteria
- [ ] AT-<k>: <observable result>  — verify with `<command>`
- [ ] Lint/typecheck clean: `<command>`

## Test command
`<command scoped to this WP>`

## Out of scope
- <explicitly excluded work>

## Notes for implementer
- Patterns to copy: <file:line>
- Pitfalls: <known risks>
