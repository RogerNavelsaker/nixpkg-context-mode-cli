# nixpkg-context-mode-mcp

Thin Nix and Flox packaging repo for the Bun-installable `context-mode-mcp` server package.

This repo should own only reproducible Nix packaging. It should not own Pi-specific install behavior or generic MCP package docs.

## Current Status

- Exposes the MCP server binary as `context-mode-mcp`
- Fetches the tagged `context-mode-mcp` source archive from GitHub
- Uses the package repo’s Bun lock surface with `bun2nix`

## Files

- `flake.nix`
- `flake.lock`
- `bun.lock`
- `bun.nix`
- `nix/package-manifest.json`
- `nix/package.nix`
- `scripts/sync-from-upstream.sh`

## Direction

The source of truth for this repo is now the `context-mode-mcp` GitHub release stream. Syncing a new version means:

- cloning the tagged `context-mode-mcp` repo
- copying its `bun.lock`
- regenerating `bun.nix`
- pinning the tagged source archive hash in `nix/package-manifest.json`
