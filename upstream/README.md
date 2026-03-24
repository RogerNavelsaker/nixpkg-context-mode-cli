# context-mode-cli

Thin Bun CLI wrapper for the shared `context-mode-mcp` server.

It speaks MCP over stdio, so it reuses the same server/runtime as other agents instead of reimplementing Context Mode logic.

## Commands

```bash
context-mode-cli list-tools
context-mode-cli stats
context-mode-cli doctor
context-mode-cli fetch-and-index https://vg.no
context-mode-cli search "main heading"
context-mode-cli tool ctx_fetch_and_index --input-json '{"url":"https://vg.no"}' --json
```

## Runtime

By default, the CLI spawns `context-mode-mcp` from `PATH`.

Environment overrides:

```bash
CONTEXT_MODE_CLI_COMMAND=/abs/path/context-mode-cli
CONTEXT_MODE_MCP_COMMAND=/abs/path/context-mode-mcp
CONTEXT_MODE_MCP_CWD=/path/to/project
```
