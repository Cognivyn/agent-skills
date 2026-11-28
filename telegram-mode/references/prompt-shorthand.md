# Developer Prompt Shorthand

Use this 4-line structure to keep prompts short without introducing ambiguity
that triggers extra clarifying turns:

```text
GOAL: <action + target>
CTX: <file / module / error>
CONSTR: <must / must-not / runtime>
DONE: <test or verify command>
```

## Example

Verbose (~45 tokens):
> "Hey, could you please check `auth.ts` and fix the bug where expired refresh
> tokens are not deleted? Make sure we use Bun and keep existing tests passing."

Shorthand (~22 tokens):
```text
FIX: auth.ts — delete expired refresh tokens.
CONSTR: bun, keep existing tests passing.
DONE: bun test
```
