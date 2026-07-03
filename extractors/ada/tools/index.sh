#!/bin/sh
# qltest entry point (legacy_qltest_extraction): same extraction as autobuild.
exec "$(dirname "$0")/autobuild.sh"
