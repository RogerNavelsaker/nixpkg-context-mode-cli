#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
manifest_path="$repo_root/nix/package-manifest.json"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi
if ! command -v nix >/dev/null 2>&1; then
  echo "nix is required" >&2
  exit 1
fi

owner="$(jq -r '.upstream.owner' "$manifest_path")"
repo="$(jq -r '.upstream.repo' "$manifest_path")"
requested_tag="${1:-}"

if [ -n "$requested_tag" ]; then
  tag="$requested_tag"
else
  tag="$(
    git ls-remote --tags --refs "https://github.com/$owner/$repo.git" 'v*' \
      | awk -F/ '{print $3}' \
      | sort -V \
      | tail -n 1
  )"
fi

if [ -z "$tag" ]; then
  echo "failed to determine upstream tag" >&2
  exit 1
fi

rev="$(
  git ls-remote "https://github.com/$owner/$repo.git" "refs/tags/$tag^{}" "refs/tags/$tag" \
    | tail -n 1 \
    | awk '{print $1}'
)"

if [ -z "$rev" ]; then
  echo "failed to resolve upstream revision for $tag" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "syncing $owner/$repo $tag ($rev)"
git clone --depth 1 --branch "$tag" "https://github.com/$owner/$repo.git" "$tmpdir/upstream" >/dev/null 2>&1

cp "$tmpdir/upstream/bun.lock" "$repo_root/bun.lock"

nix run github:nix-community/bun2nix?tag=2.0.8 -- \
  -l "$repo_root/bun.lock" \
  -o "$repo_root/bun.nix"

src_hash="$(
  nix store prefetch-file --json --unpack "https://github.com/$owner/$repo/archive/refs/tags/$tag.tar.gz" \
    | jq -r '.hash'
)"

version="$(jq -r '.version' "$tmpdir/upstream/package.json")"
homepage="$(jq -r '.homepage' "$tmpdir/upstream/package.json")"
license="$(jq -r '.license' "$tmpdir/upstream/package.json")"

jq -n \
  --arg owner "$owner" \
  --arg repo "$repo" \
  --arg tag "$tag" \
  --arg rev "$rev" \
  --arg version "$version" \
  --arg hash "$src_hash" \
  --arg homepage "$homepage" \
  --arg license "$license" \
  '{
    stubbed: false,
    upstream: {
      owner: $owner,
      repo: $repo,
      tag: $tag,
      rev: $rev,
      version: $version,
      hash: $hash
    },
    binary: {
      name: "context-mode-mcp",
      entrypoint: "bin/context-mode-mcp.mjs"
    },
    meta: {
      description: "Thin Nix package for the Context Mode MCP server",
      homepage: $homepage,
      licenseSpdx: $license
    }
  }' > "$manifest_path"

echo "updated:"
echo "  manifest: $manifest_path"
echo "  lockfile: $repo_root/bun.lock"
echo "  deps nix: $repo_root/bun.nix"
