#!/bin/bash
# Build Libadalang + Python bindings from source (burndown 1.1).
#
# Follows the official procedure from the Libadalang user manual: gnatcoll-core,
# gnatcoll-bindings (gmp, iconv), adasat, langkit_support, then libadalang via
# `lkm make`, all from matching branches. Tested on Debian 13 (WSL) with apt-provided
# gnat/gprbuild. Usage: build-libadalang.sh [stage]  (default: all)
#
# Debian prerequisites:
#   apt-get install git build-essential gnat gprbuild python3 python3-venv \
#     python3-dev libgmp-dev pkg-config libxmlada-dom-dev libxmlada-input-dev \
#     libxmlada-sax-dev libxmlada-schema-dev libxmlada-unicode-dev

set -euo pipefail

BRANCH="${LAL_BRANCH:-master}"
SRC="$HOME/src"
PREFIX="$HOME/adacore"
VENV="$HOME/lal-venv"
JOBS="$(nproc)"
LIBTYPES="relocatable"   # Python bindings need shared libs; static skipped for build time

export PATH="$PREFIX/bin:$PATH"
export GPR_PROJECT_PATH="$PREFIX/share/gpr:${GPR_PROJECT_PATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"

stage="${1:-all}"

run_stage() { [ "$stage" = all ] || [ "$stage" = "$1" ]; }

mkdir -p "$SRC" "$PREFIX"

if run_stage clone; then
  cd "$SRC"
  for repo in gnatcoll-core gnatcoll-bindings adasat VSS prettier-ada langkit libadalang; do
    [ -d "$repo" ] || git clone --depth 1 -b "$BRANCH" "https://github.com/AdaCore/$repo.git"
  done
fi

if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"

if run_stage gnatcoll-core; then
  cd "$SRC/gnatcoll-core"
  make prefix="$PREFIX" LIBRARY_TYPES="$LIBTYPES" BUILD=PROD PROCESSORS="$JOBS" build install
fi

if run_stage gnatcoll-bindings; then
  for binding in gmp iconv; do
    cd "$SRC/gnatcoll-bindings/$binding"
    python3 setup.py build -j"$JOBS" --prefix="$PREFIX" --library-types="$LIBTYPES" --reconfigure
    python3 setup.py install --prefix="$PREFIX"
  done
fi

if run_stage adasat; then
  cd "$SRC/adasat"
  gprbuild -j"$JOBS" -P adasat.gpr -XLIBRARY_TYPE=relocatable -XBUILD_MODE=prod -p
  gprinstall -P adasat.gpr -XLIBRARY_TYPE=relocatable -XBUILD_MODE=prod \
    --prefix="$PREFIX" --sources-subdir=include/adasat -p -f
fi

# VSS and prettier-ada are needed by langkit_support (master, since ~25.x)
if run_stage vss; then
  cd "$SRC/VSS"
  make build-libs-release_relocatable PREFIX="$PREFIX"
  make install-libs-release_relocatable PREFIX="$PREFIX"
fi

if run_stage prettier-ada; then
  cd "$SRC/prettier-ada"
  gprbuild -j"$JOBS" -p -P prettier_ada.gpr \
    -XLIBRARY_TYPE=relocatable -XPRETTIER_ADA_LIBRARY_TYPE=relocatable \
    -XPRETTIER_ADA_BUILD_MODE=prod
  gprinstall -P prettier_ada.gpr -p -f --prefix="$PREFIX" \
    -XLIBRARY_TYPE=relocatable -XPRETTIER_ADA_LIBRARY_TYPE=relocatable \
    -XPRETTIER_ADA_BUILD_MODE=prod --sources-subdir=include/prettier_ada
fi

if run_stage langkit; then
  cd "$SRC/langkit"
  pip install .
  python manage.py build-langkit-support --library-types="$LIBTYPES" --build-mode=dev
  python manage.py install-langkit-support "$PREFIX" --library-types="$LIBTYPES" --build-mode=dev
fi

if run_stage libadalang; then
  cd "$SRC/libadalang"
  pip install -r requirements-pypi.txt
  python -m langkit.scripts.lkm make --library-types="$LIBTYPES" --build-mode=dev -j"$JOBS"
  python -m langkit.scripts.lkm install "$PREFIX" --library-types="$LIBTYPES" --build-mode=dev
fi

echo "=== build-libadalang: stage '$stage' OK ==="
echo "To use: source $VENV/bin/activate && eval \"\$(cd $SRC/libadalang && python -m langkit.scripts.lkm printenv)\""
