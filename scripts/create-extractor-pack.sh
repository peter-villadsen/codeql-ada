#!/bin/bash
# Build the release tarball codeql-extractor-ada-linux64.tar.gz (D-010, burndown 6.1).
# Runs in WSL/Debian 13 (or the matching CI container). Bundles the Libadalang runtime
# (shared-library closure + ctypes Python bindings) into extractors/ada so target
# machines need only a system Python >= 3.11 and their own CodeQL CLI.
#
# Input:  ADA_LAL_PREFIX (default $HOME/adacore) — a prefix built by
#         scripts/build-libadalang.sh.
# Output: extractor-pack/ (staging dir) and codeql-extractor-ada-linux64.tar.gz,
#         both in the current working directory.

set -euo pipefail

ADA_LAL_PREFIX="${ADA_LAL_PREFIX:-$HOME/adacore}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK_DIR="extractor-pack"
TARBALL="codeql-extractor-ada-linux64.tar.gz"

[ -d "$ADA_LAL_PREFIX/lib" ] || { echo "ERROR: $ADA_LAL_PREFIX/lib not found (build Libadalang first)." >&2; exit 1; }

rm -rf "$PACK_DIR" "$TARBALL"
mkdir -p "$PACK_DIR/ada"

# --- base extractor pack (autobuild.sh/index.sh/extractor.py/ada_tables.json,
# codeql-extractor.yml, ada.dbscheme, THIRD_PARTY_NOTICES.md, LICENSE) ---
cp -a "$REPO_ROOT/extractors/ada/." "$PACK_DIR/ada/"

# --- step 1: shared-library closure ---
# Core glibc / base-Debian pieces every target machine already has; never bundle these.
# libgcc_s is excluded here and verified present-on-target by the isolation test (step 7).
is_excluded_lib() {
  case "$1" in
    libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|ld-linux*.so*|linux-vdso.so*|libgcc_s.so*) return 0 ;;
    *) return 1 ;;
  esac
}

LIB_DIR="$PACK_DIR/ada/lal/lib"
mkdir -p "$LIB_DIR"
cp -a "$ADA_LAL_PREFIX/lib/." "$LIB_DIR/"

# Resolve the full transitive closure of every bundled .so via ldd, with the prefix's
# own lib dir on LD_LIBRARY_PATH so intra-closure deps (e.g. libadalang.so ->
# liblangkit_support.so) resolve instead of showing "not found".
resolved="$(mktemp)"
trap 'rm -f "$resolved"' EXIT
find "$ADA_LAL_PREFIX/lib" -type f -name '*.so*' -print0 |
  while IFS= read -r -d '' so; do
    LD_LIBRARY_PATH="$ADA_LAL_PREFIX/lib:${LD_LIBRARY_PATH:-}" ldd "$so"
  done > "$resolved"

if grep -q ' not found' "$resolved"; then
  echo "ERROR: unresolved shared-library dependency in the closure:" >&2
  grep ' not found' "$resolved" >&2
  exit 1
fi

awk '$2 == "=>" && $3 != "" { print $3 }' "$resolved" | sort -u |
  while IFS= read -r dep; do
    name="$(basename "$dep")"
    is_excluded_lib "$name" && continue
    [ -e "$LIB_DIR/$name" ] && continue
    # -L: these come from outside the prefix (e.g. /usr/lib/x86_64-linux-gnu), often as a
    # dev symlink to a versioned real file (libgmp.so.10 -> libgmp.so.10.5.0). Dereference
    # so the bundled copy is the real file named after the requested SONAME, not a symlink
    # dangling outside the pack.
    cp -L "$dep" "$LIB_DIR/$name"
  done

# --- step 2: python bindings (must be pure Python + ctypes, no native extensions) ---
if find "$ADA_LAL_PREFIX/python/libadalang" \( -name '*.so' -o -name '*.pyd' \) -print -quit | grep -q .; then
  echo "ERROR: libadalang python bindings contain native extensions (*.so/*.pyd)." >&2
  echo "This breaks D-010's 'any Python >= 3.11' claim -- stop and report, do not guess a fix." >&2
  exit 1
fi
mkdir -p "$PACK_DIR/ada/lal/python"
cp -a "$ADA_LAL_PREFIX/python/libadalang" "$PACK_DIR/ada/lal/python/"

# share/gpr: small (<1MB) text .gpr files that a target project's own GPR closure may
# `with` (e.g. a user project depending on gnatcoll) -- autobuild.sh points
# GPR_PROJECT_PATH here, so it must exist for that to mean anything.
mkdir -p "$PACK_DIR/ada/lal/share"
cp -a "$ADA_LAL_PREFIX/share/gpr" "$PACK_DIR/ada/lal/share/"

# --- step 4 cleanup: no spike leftovers in the pack copy either ---
rm -f "$PACK_DIR/ada/tools/spike_extractor.py"

# --- step 6: tar, preserving exec bits ---
tar -C "$PACK_DIR" -czf "$TARBALL" ada

echo "=== create-extractor-pack: built $TARBALL ==="
tar -tvzf "$TARBALL" | grep -E 'autobuild\.sh|index\.sh' || {
  echo "ERROR: autobuild.sh/index.sh missing from tarball." >&2
  exit 1
}
