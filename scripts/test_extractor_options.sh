#!/bin/bash
# Regression test for the extractor's project options (D-036): builds small databases and
# checks which files were extracted, and that a call across a multi-unit file resolves.
#
# Run inside the WSL/Linux environment the extractor runs in, from the repository root:
#   bash scripts/test_extractor_options.sh
# Needs codeql on PATH and the Libadalang environment (see docs/user-guide.md).
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$(mktemp -d)}
FAILS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

# create <name> <source dir> [codeql args...]: builds $WORK/<name>-db, log in $WORK/<name>.log
create() {
  local name=$1 src=$2; shift 2
  rm -rf "$WORK/$name-db"
  codeql database create "$WORK/$name-db" --language=ada --build-mode=none \
    --search-path="$REPO/extractors" --source-root="$src" "$@" > "$WORK/$name.log" 2>&1
}

# extracted <name> <file>: whether the extractor reported extracting a file of that name
# (the CLI prefixes each extractor line with a timestamp and "[build-stdout]")
extracted() { grep -q "\[ada-extractor\] /.*/$2\$" "$WORK/$1.log"; }

# --- scenario variables choose the project's sources --------------------------------
P=$WORK/scenario; rm -rf "$P"; mkdir -p "$P/src_a" "$P/src_b"
cat > "$P/demo.gpr" <<'EOF'
project Demo is
   type Mode_T is ("a", "b");
   Mode : Mode_T := external ("MODE", "a");
   for Source_Dirs use ("src_" & Mode);
end Demo;
EOF
echo "package Only_A is end Only_A;" > "$P/src_a/only_a.ads"
echo "package Only_B is end Only_B;" > "$P/src_b/only_b.ads"
create scenario "$P" --extractor-option=ada.scenario=MODE=b
if extracted scenario only_b.ads && ! extracted scenario only_a.ads; then
  pass "scenario=MODE=b selects src_b"
else
  fail "scenario=MODE=b selects src_b (see $WORK/scenario.log)"
fi
create scenario-env "$P"
if extracted scenario-env only_a.ads && ! extracted scenario-env only_b.ads; then
  pass "default scenario selects src_a"
else
  fail "default scenario selects src_a (see $WORK/scenario-env.log)"
fi

# --- a project's Naming package names its sources -----------------------------------
P=$WORK/naming; rm -rf "$P"; mkdir -p "$P"
cat > "$P/legacy.gpr" <<'EOF'
project Legacy is
   package Naming is
      for Spec_Suffix ("Ada") use ".spc";
      for Body_Suffix ("Ada") use ".bdy";
   end Naming;
end Legacy;
EOF
printf 'package Util is\n   procedure Run;\nend Util;\n' > "$P/util.spc"
printf 'package body Util is\n   procedure Run is null;\nend Util;\n' > "$P/util.bdy"
create naming "$P"
if extracted naming util.spc && extracted naming util.bdy; then
  pass "a project's Naming package (.spc/.bdy) is followed"
else
  fail "a project's Naming package (.spc/.bdy) is followed (see $WORK/naming.log)"
fi

# --- without a project: extra extensions, and several units in one file -------------
P=$WORK/legacy; rm -rf "$P"; mkdir -p "$P"
cat > "$P/units.a" <<'EOF'
package Counter is
   procedure Bump;
end Counter;

package body Counter is
   N : Integer := 0;
   procedure Bump is
   begin
      N := N + 1;
   end Bump;
end Counter;
EOF
cat > "$P/main.a" <<'EOF'
with Counter;
procedure Main is
begin
   Counter.Bump;
end Main;
EOF
create legacy-noext "$P"
if ! extracted legacy-noext units.a; then
  pass "a .a file is not read by default"
else
  fail "a .a file is not read by default (see $WORK/legacy-noext.log)"
fi
create legacy "$P" --extractor-option=ada.extensions=.a
if extracted legacy units.a && extracted legacy main.a; then
  pass "extensions=.a reads .a files"
else
  fail "extensions=.a reads .a files (see $WORK/legacy.log)"
fi
Q=$WORK/calls.ql
mkdir -p "$WORK/q"
cat > "$WORK/q/qlpack.yml" <<'EOF'
name: test/extractor-options
version: 0.0.0
dependencies:
  peter-villadsen/ada-all: "*"
EOF
cat > "$WORK/q/calls.ql" <<'EOF'
import ada

from Call c
select c.getTarget().getQualifiedName()
EOF
codeql pack install "$WORK/q" --additional-packs="$REPO/ql" > "$WORK/pack.log" 2>&1
out=$(codeql query run --database="$WORK/legacy-db" --additional-packs="$REPO/ql" \
  --search-path="$REPO/extractors" "$WORK/q/calls.ql" 2>&1)
if echo "$out" | grep -qi "Counter.Bump"; then
  pass "a call into a multi-unit .a file resolves (Counter.Bump)"
else
  fail "a call into a multi-unit .a file resolves: $out"
fi

# --- a malformed option stops extraction --------------------------------------------
create bad "$WORK/scenario" --extractor-option=ada.scenario=MODE
if grep -qi "scenario" "$WORK/bad.log" && ! grep -q "Successfully created database" "$WORK/bad.log"; then
  pass "a malformed scenario is rejected"
else
  fail "a malformed scenario is rejected (see $WORK/bad.log)"
fi

echo
[ $FAILS -eq 0 ] && echo "All extractor option checks passed." || echo "$FAILS check(s) failed. Logs: $WORK"
exit $FAILS
