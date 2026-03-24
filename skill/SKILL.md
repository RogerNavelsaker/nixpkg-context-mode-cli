---
name: context-mode
description: Use context-mode-cli for large-output shell tasks, fetch-and-index workflows, and context-safe search over indexed content.
---

# Context Mode

Use this skill when the task would otherwise flood chat with raw output.

Preferred commands:

```bash
context-mode-cli stats
context-mode-cli doctor
context-mode-cli fetch-and-index "https://example.com"
context-mode-cli search "main heading"
context-mode-cli tool ctx_execute --input-json '{"language":"shell","code":"git log --oneline | head -200"}'
```

Rules:
- Prefer `context-mode-cli` over raw `curl`, `wget`, or large inline shell output.
- Use `fetch-and-index` first, then `search`.
- Use `tool ctx_execute` for large shell output.
