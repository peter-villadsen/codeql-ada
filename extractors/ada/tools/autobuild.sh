#!/bin/sh
# Ada extractor autobuild: requires a Python with the libadalang module.
# ADA_EXTRACTOR_PYTHON / ADA_LAL_PREFIX allow pointing at a local LAL build
# (see scripts/build-libadalang.sh). Prefix resolution: explicit ADA_LAL_PREFIX
# wins; else the bundled runtime shipped in a release tarball
# ($CODEQL_EXTRACTOR_ADA_ROOT/lal, see scripts/create-extractor-pack.sh) if
# present; else the dev-workflow default of $HOME/adacore.
PYTHON="${ADA_EXTRACTOR_PYTHON:-python3}"
if [ -n "${ADA_LAL_PREFIX:-}" ]; then
  PREFIX="$ADA_LAL_PREFIX"
elif [ -d "$CODEQL_EXTRACTOR_ADA_ROOT/lal" ]; then
  PREFIX="$CODEQL_EXTRACTOR_ADA_ROOT/lal"
else
  PREFIX="$HOME/adacore"
fi
export PYTHONPATH="$PREFIX/python:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
export GPR_PROJECT_PATH="$PREFIX/share/gpr:${GPR_PROJECT_PATH:-}"
exec "$PYTHON" "$CODEQL_EXTRACTOR_ADA_ROOT/tools/extractor.py"
