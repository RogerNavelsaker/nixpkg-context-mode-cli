# nixpkg-context-mode-cli

Thin Nix and Flox packaging repo for the Bun-installable `context-mode-cli` bridge package.

This repo should own only reproducible Nix packaging. It should not own Pi-specific install behavior or generic MCP package docs.

## Current Status

- Exposes the CLI binary as `context-mode-cli`
- Packages the local `context-mode-cli` source tree
- Uses the package repo’s Bun lock surface with `bun2nix`
- Wraps the CLI with Bun from the Nix store, so Bun does not need to be installed separately in Flox
- Carries a package revision separate from upstream so Flox can detect packaging-only updates

## Files

- `flake.nix`
- `flake.lock`
- `bun.lock`
- `bun.nix`
- `nix/package-manifest.json`
- `nix/package.nix`
- `scripts/sync-from-upstream.sh`

## Direction

The source of truth for this repo is the local `context-mode-cli` package repo until it is published. Syncing a new version means:

- copying the current `context-mode-cli` `bun.lock`
- copying its `bun.lock`
- regenerating `bun.nix`
- bumping `nix/package-manifest.json`
