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
  for repo in gnatcoll-core gnatcoll-bindings adasat VSS langkit libadalang; do
    [ -d "$repo" ] || git clone --depth 1 -b "$BRANCH" "https://github.com/AdaCore/$repo.git"
  done
  # prettier-ada defaults to `main`, not `master` like the rest of this group;
  # it isn't pinned in lockstep with LAL_BRANCH, so just take its own default.
  [ -d prettier-ada ] || git clone --depth 1 https://github.com/AdaCore/prettier-ada.git
fi

if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"

if run_stage gnatcoll-core && [ ! -f "$PREFIX/share/gpr/gnatcoll_core.gpr" ]; then
  cd "$SRC/gnatcoll-core"
  # The Makefile ignores prefix= and installs to ./gnatcoll-core-install; its
  # gnatcoll_projects component fails (wants libgpr) but LAL doesn't need it.
  make LIBRARY_TYPES="$LIBTYPES" BUILD=PROD PROCESSORS="$JOBS" build install \
    || echo "gnatcoll-core: tolerating partial failure (gnatcoll_projects)"
  cp -a "$SRC/gnatcoll-core/gnatcoll-core-install/." "$PREFIX/"
  test -f "$PREFIX/share/gpr/gnatcoll_core.gpr"
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

# Liblktlang (parser for the Lkt DSL that LAL's grammar is written in) is built
# from bootstrap sources bundled inside the langkit repo — it has no repo of its own.
# GNAT 14 (Debian) doesn't know some aspects langkit master emits for GNAT 25+;
# they are warnings, but dev build mode turns warnings into errors. Build prod
# and keep warnings non-fatal.
GARGS="-cargs:ada -gnatws"

if run_stage lkt; then
  # Standalone liblktlang vendors AdaSAT; langkit expects the checkout here.
  [ -e "$SRC/langkit/langkit/adasat" ] || ln -s "$SRC/adasat" "$SRC/langkit/langkit/adasat"
  # The bootstrap gpr hardcodes -gnatwe (warnings as errors) in dev mode; GNAT 14
  # warns about unknown GNAT-25 aspects in the generated code, so strip it.
  sed -i 's/("-gnatwe", "-gnata")/("-gnata")/' "$SRC/langkit/lkt/bootstrap/liblktlang.gpr"
  cd "$SRC/langkit"
  python manage.py make --library-types="$LIBTYPES" --build-mode prod --lib lkt --no-mypy
fi

# LAL's generated libadalang.gpr imports gnatcoll_projects and gpr2 (project
# provider). gnatcoll_projects needs libgpr (from the gprbuild repo); gpr2 comes
# from the AdaCore/gpr repo. None are packaged in Debian.
if run_stage libgpr; then
  # v25.0.0 tag: master targets GNAT Pro 26 runtime internals absent from FSF GNAT 14.
  [ -d "$SRC/gprbuild" ] || git clone --depth 1 -b v25.0.0 https://github.com/AdaCore/gprbuild.git "$SRC/gprbuild"
  cd "$SRC/gprbuild"
  # Put_Resource_Usage (unix flavor) needs GNAT.Sockets.Thin_Common.Timeval,
  # which FSF GNAT lacks; the null flavor is a no-op stub and fine for libgpr.
  sed -i 's/gpr-util-put_resource_usage__unix.adb/gpr-util-put_resource_usage__null.adb/' gpr/gpr.gpr
  make prefix="$PREFIX" BUILD=production setup
  # gnatcoll_projects builds both static and shared; the installed gpr.gpr only
  # accepts build kinds that were actually installed, so provide both.
  make LIBGPR_TYPES="static static-pic shared" libgpr.build libgpr.install
fi

if run_stage gnatcoll-projects; then
  cd "$SRC/gnatcoll-core"
  python projects/gnatcoll_projects.gpr.py build --jobs="$JOBS" --build=PROD \
    --prefix="$PREFIX" --install --enable-shared=yes
fi

if run_stage gpr2; then
  # v26.0.0: LAL master needs GPR2.Reporter (absent in v25); gpr2 master uses the
  # Ada 2022 'finally' construct that GNAT 14 cannot parse yet.
  [ -d "$SRC/gpr" ] || git clone --depth 1 -b v26.0.0 https://github.com/AdaCore/gpr.git "$SRC/gpr"
  # gpr2's embedded compiler knowledge base is generated from this repo
  [ -d "$SRC/gprconfig_kb" ] || git clone --depth 1 https://github.com/AdaCore/gprconfig_kb.git "$SRC/gprconfig_kb"
  cd "$SRC/gpr"
  make prefix="$PREFIX" LIBGPR2_TYPES=relocatable setup build-libs install-libs
  # gprinstall wrongly records two Ada separates as library interface units,
  # which breaks builds against the installed project.
  sed -i 's/"gpr2.build.view_tables.update_sources_list", //; s/"gpr2.tree_internal.load_autoconf", //' \
    "$PREFIX/share/gpr/gpr2.gpr"
  # The install omits some private sources (e.g. jobserver pipe protocol) that
  # clients need visible when building with cross-unit inlining.
  cp -n "$SRC/gpr/src/lib/"*.ad? "$SRC/gpr/src/build/"*.ad? "$SRC/gpr/src/private/"*.ad? \
    "$PREFIX/include/gpr2.relocatable/" 2>/dev/null || true
  # Same for the Langkit-generated gpr_parser embedded in the gpr2 library.
  cp -n "$SRC/gpr/langkit/gen/src/"*.ad? "$PREFIX/include/gpr2.relocatable/" 2>/dev/null || true
fi

if run_stage libadalang; then
  cd "$SRC/langkit"
  # printenv output references possibly-unset vars (C_INCLUDE_PATH etc.)
  set +u
  eval "$(python manage.py printenv --build-mode prod)"
  set -u
  cd "$SRC/libadalang"
  pip install -r requirements-pypi.txt
  python -m langkit.scripts.lkm make --library-types="$LIBTYPES" --build-mode=prod -j"$JOBS"
  python -m langkit.scripts.lkm install "$PREFIX" --library-types="$LIBTYPES" --build-mode=prod
fi

echo "=== build-libadalang: stage '$stage' OK ==="
echo "To use: source $VENV/bin/activate && eval \"\$(cd $SRC/libadalang && python -m langkit.scripts.lkm printenv)\""
