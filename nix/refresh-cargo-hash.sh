#!/usr/bin/env bash
# Refresh nix/package.nix's `cargoHash` for the current Cargo.lock.
#
# The flake builds the working tree (local `src`), so `nix-update` can't bump
# this hash — it tracks a *remote* version, which a local src doesn't have. The
# vendored-deps hash still changes on every Cargo.lock change, so recompute it
# the standard way: set a fake hash, let Nix report the real one, write it back.
#
# The cargoHash check fails at the cargo-deps fixed-output derivation, before
# gpui is compiled, so this is fast. Run after any dependency / lockfile change.
set -euo pipefail

cd "$(dirname "$0")/.."
file="nix/package.nix"
fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current=$(sed -n 's/.*cargoHash = "\(sha256-[^"]*\)";.*/\1/p' "$file")
[ -n "$current" ] || { echo "no cargoHash found in $file" >&2; exit 1; }

# Portable in-place rewrite (works with both GNU and BSD sed).
set_hash() {
  local tmp
  tmp=$(mktemp)
  sed "s|cargoHash = \"sha256-[^\"]*\";|cargoHash = \"$1\";|" "$file" >"$tmp"
  mv "$tmp" "$file"
}

restore() { set_hash "$current"; }
trap restore EXIT

set_hash "$fake"
# Capture the build to a file, then parse — piping `nix build` straight into a
# command substitution drops the mismatch error.
build_log=$(mktemp)
nix build .#openlogi -L >"$build_log" 2>&1 || true
got=$(sed -n 's|.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*|\1|p' "$build_log" | head -1)
rm -f "$build_log"
[ -n "$got" ] || { echo "could not determine cargoHash from the build output" >&2; exit 1; }

trap - EXIT
set_hash "$got"

if [ "$got" = "$current" ]; then
  echo "cargoHash already up to date ($got)"
else
  echo "cargoHash: $current -> $got"
fi
