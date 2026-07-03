#!/bin/sh
# Ada extractor autobuild: requires a Python with the libadalang module.
# ADA_EXTRACTOR_PYTHON / ADA_LAL_PREFIX allow pointing at a local LAL build
# (see scripts/build-libadalang.sh); packaging will bundle these later.
PYTHON="${ADA_EXTRACTOR_PYTHON:-python3}"
PREFIX="${ADA_LAL_PREFIX:-$HOME/adacore}"
export PYTHONPATH="$PREFIX/python:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
export GPR_PROJECT_PATH="$PREFIX/share/gpr:${GPR_PROJECT_PATH:-}"
exec "$PYTHON" "$CODEQL_EXTRACTOR_ADA_ROOT/tools/extractor.py"
