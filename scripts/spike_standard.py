"""Spike for burndown 8.12: can package Standard and the GNAT runtime specs be
extracted as pseudo-sources, and what would it cost?

Two modes (inside the WSL build env):

  python spike_standard.py probe <dir>
      Resolve every name in the Ada files under <dir> (auto unit provider, the
      extractor's fallback) and report where each out-of-source target lives,
      plus the shape of the Standard unit itself.

  python spike_standard.py closure <dir> [<project.gpr>]
      Over a whole project: which out-of-source units do xref / expr-type /
      generic-instantiation / body-part targets land in, how many AST nodes
      would extracting them add, and how does that compare with the project.

Set SPIKE_RUNTIME=<adainclude dir> to hand the GNAT runtime specs to the auto
provider (resolvable, not counted as project files). Findings from running this:
docs/phase8.12-plan.md.
"""

import collections
import os
import pathlib
import sys
import time

import libadalang as lal

EXTENSIONS = {".ads", ".adb", ".ada"}


def norm(path) -> str:
    return str(pathlib.Path(path).resolve()).replace("\\", "/")


def ada_files(root):
    return sorted(str(p) for p in pathlib.Path(root).rglob("*")
                  if p.suffix.lower() in EXTENSIONS and p.is_file())


def context(root, gpr=None):
    if gpr:
        prj = lal.GPRProject(gpr)
        files = [f for f in prj.source_files()
                 if pathlib.Path(f).suffix.lower() in EXTENSIONS]
        return prj.create_context(), files
    files = ada_files(root)
    # SPIKE_RUNTIME=<adainclude dir>: also hand the runtime specs to the auto
    # provider (they are *not* extracted, only made resolvable).
    rt = os.environ.get("SPIKE_RUNTIME")
    extra = ada_files(rt) if rt else []
    provider = lal.UnitProvider.auto(input_files=files + extra)
    return lal.AnalysisContext(unit_provider=provider), files


def count_nodes(unit):
    if unit.root is None:
        return 0
    return sum(1 for _ in unit.root.finditer(lambda n: True))


def targets(node):
    """Yield (relation, target) for every semantic relation the extractor emits."""
    if isinstance(node, lal.Name) and not node.p_is_defining:
        yield "xref", node.p_referenced_decl()
    if isinstance(node, lal.Expr):
        yield "type", node.p_expression_type
    if isinstance(node, lal.GenericInstantiation):
        yield "generic", node.p_designated_generic_decl
    if isinstance(node, lal.BasicDecl):
        bp = getattr(node, "p_body_part", None)
        yield "body", bp() if callable(bp) else bp


def safe_targets(node):
    try:
        for rel, t in targets(node):
            if t is not None:
                yield rel, t
    except Exception:
        return


def probe(root, gpr=None):
    ctx, files = context(root, gpr)
    sources = {norm(f) for f in files}
    std = None
    for f in files:
        u = ctx.get_from_file(f)
        if u.root is None:
            continue
        if std is None:
            std = u.root.p_standard_unit
        for n in u.root.finditer(lambda n: True):
            if isinstance(n, lal.Identifier) and not n.p_is_defining:
                try:
                    if n.p_referenced_decl() is None:
                        print(f"UNRESOLVED {n.text!r} at {n.sloc_range}")
                except Exception as e:
                    print(f"ERROR      {n.text!r} at {n.sloc_range}: {type(e).__name__}")
            for rel, t in safe_targets(n):
                fn = t.unit.filename
                if norm(fn) in sources or "__standard" in fn:
                    continue
                print(f"{rel:7} {n.text[:40]!r:44} -> {t.kind_name} "
                      f"{(t.text.splitlines() or [''])[0][:50]!r} @ {fn}:{t.sloc_range}")

    print("\n== Standard unit ==")
    print("filename:", repr(std.filename))
    print("resolved filename:", norm(std.filename))
    print("root:", std.root.kind_name if std.root else None)
    print("text length:", len(std.text), "lines:", std.text.count("\n"))
    print("nodes:", count_nodes(std))
    print("diagnostics:", len(std.diagnostics))
    first = std.first_token
    print("first token:", first.kind, repr(first.text), first.sloc_range)
    print("--- first 30 lines ---")
    print("\n".join(std.text.splitlines()[:30]))


def closure(root, gpr=None):
    t0 = time.monotonic()
    ctx, files = context(root, gpr)
    sources = {norm(f) for f in files}
    proj_nodes = 0
    rel_counts = collections.Counter()      # (rel, in/out) -> rows
    out_units = collections.Counter()       # filename -> referencing rows
    names = collections.Counter()           # outcome of p_referenced_decl
    for f in files:
        u = ctx.get_from_file(f)
        if u.root is None:
            continue
        proj_nodes += count_nodes(u)
        for n in u.root.finditer(lambda n: True):
            if isinstance(n, lal.Identifier) and not n.p_is_defining:
                try:
                    names["resolved" if n.p_referenced_decl() is not None
                          else "unresolved"] += 1
                except Exception:
                    names["error"] += 1
            for rel, t in safe_targets(n):
                fn = norm(t.unit.filename)
                inside = fn in sources
                rel_counts[rel, inside] += 1
                if not inside:
                    out_units[t.unit.filename] += 1
    t_proj = time.monotonic() - t0

    # Direct set: the units the project's rows point into.
    direct = set(out_units)
    # Transitive: extracting a unit means walking it, whose own names point
    # further out. Fixed point over out-of-source units only.
    trans, work = set(direct), list(direct)
    t0 = time.monotonic()
    while work:
        u = ctx.get_from_file(work.pop())
        if u.root is None:
            continue
        for n in u.root.finditer(lambda n: True):
            for _, t in safe_targets(n):
                fn = t.unit.filename
                if norm(fn) not in sources and fn not in trans:
                    trans.add(fn)
                    work.append(fn)
    t_trans = time.monotonic() - t0

    def nodes_of(names):
        return sum(count_nodes(ctx.get_from_file(n)) for n in names)

    print(f"project: {root} ({gpr or 'auto provider'})")
    print(f"files: {len(files)}, nodes: {proj_nodes}, analysis {t_proj:.1f}s")
    tot = sum(names.values()) or 1
    print("identifiers: " + ", ".join(
        f"{k} {names[k]} ({100 * names[k] / tot:.1f}%)"
        for k in ("resolved", "unresolved", "error")))
    for rel in ("xref", "type", "generic", "body"):
        i, o = rel_counts[rel, True], rel_counts[rel, False]
        tot = i + o
        pct = 100 * o / tot if tot else 0
        print(f"  {rel:8} in-source {i:8}  out-of-source {o:8}  ({pct:.1f}% dropped today)")
    dn, tn = nodes_of(direct), nodes_of(trans)
    print(f"direct out-of-source units: {len(direct)}, nodes {dn} "
          f"(+{100 * dn / proj_nodes:.1f}%)")
    print(f"transitive closure units:   {len(trans)}, nodes {tn} "
          f"(+{100 * tn / proj_nodes:.1f}%), walk {t_trans:.1f}s")
    print("top referenced out-of-source units:")
    for fn, c in out_units.most_common(15):
        print(f"  {c:8}  {fn}")


def main() -> int:
    mode = sys.argv[1]
    if mode == "probe":
        probe(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif mode == "closure":
        closure(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
