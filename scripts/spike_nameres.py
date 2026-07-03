"""Spike 1.5: Libadalang name-resolution robustness/performance on a real project.

Loads a GPR project, parses every source, and attempts p_referenced_decl on every
name node, measuring throughput and failure rates. This de-risks the extractor's
xref stage (burndown 1.5 / D-005).

Usage (inside the WSL build env):
  python spike_nameres.py <project.gpr>
"""

import sys
import time

import libadalang as lal


def main() -> int:
    gpr = sys.argv[1]
    t0 = time.monotonic()
    project = lal.GPRProject(gpr)
    ctx = project.create_context()
    sources = project.source_files()
    t_load = time.monotonic() - t0
    print(f"project: {gpr}")
    print(f"sources: {len(sources)} (project load {t_load:.2f}s)")

    parse_diags = 0
    t0 = time.monotonic()
    units = []
    for f in sources:
        u = ctx.get_from_file(f)
        units.append(u)
        parse_diags += len(u.diagnostics)
    t_parse = time.monotonic() - t0
    print(f"parse: {t_parse:.2f}s ({len(units) / t_parse:.1f} files/s), "
          f"{parse_diags} diagnostics")

    names = resolved = unresolved = errors = 0
    t0 = time.monotonic()
    for u in units:
        if u.root is None:
            continue
        for node in u.root.finditer(lambda n: n.is_a(lal.Name)):
            # Only resolve usage names; defining names resolve trivially.
            if not node.is_a(lal.Identifier, lal.DottedName, lal.CharLiteral,
                             lal.StringLiteral):
                continue
            names += 1
            try:
                decl = node.p_referenced_decl()
                if decl is not None:
                    resolved += 1
                else:
                    unresolved += 1
            except lal.PropertyError:
                errors += 1
            except Exception:
                errors += 1
    t_res = time.monotonic() - t0
    rate = names / t_res if t_res else 0
    print(f"nameres: {names} names in {t_res:.2f}s ({rate:.0f} names/s)")
    if names:
        print(f"  resolved:   {resolved} ({100 * resolved / names:.1f}%)")
        print(f"  unresolved: {unresolved} ({100 * unresolved / names:.1f}%)")
        print(f"  errors:     {errors} ({100 * errors / names:.1f}%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
