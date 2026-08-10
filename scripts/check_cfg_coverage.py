#!/usr/bin/env python3
"""Check (or regenerate) the CFG coverage appendix in docs/cfg-design.md.

Every node kind in ``schema/lal-nodes.json`` must carry an explicit verdict
saying how the control-flow graph treats it, so that a future grammar addition
cannot silently slip past the CFG (decision D-016).

The verdicts are *derived from the implementation*, not maintained by hand:
this script reads ``ControlFlowGraphImpl.qll`` to find which node kinds have a
dedicated control-flow tree, which are reached by the generic post-order
expression tree, which fall to the opaque-statement leaf, and which the
implementation merely reads without ever turning into a node. Whatever is left
is not control-relevant, and is grouped by why.

    python scripts/check_cfg_coverage.py            # verify (CI); exit 1 on drift
    python scripts/check_cfg_coverage.py --write    # regenerate the appendix

Exit codes: 0 verified/written, 1 the appendix is out of date or a node kind is
unaccounted for.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMA = os.path.join(REPO, "schema", "lal-nodes.json")
IMPL = os.path.join(REPO, "ql", "lib", "codeql", "ada", "controlflow", "internal",
                    "ControlFlowGraphImpl.qll")
DOC = os.path.join(REPO, "docs", "cfg-design.md")

BEGIN = "<!-- BEGIN GENERATED COVERAGE -->"
END = "<!-- END GENERATED COVERAGE -->"

# The two catch-all trees, whose `instanceof` targets are base classes rather
# than a construct with its own shape.
CATCH_ALL = {"AdaNode", "Stmt"}

# Structural parts the implementation reaches through an accessor rather than by
# naming the type (`super.getElsePart()`, `super.getDecl()`, …), so the
# `Raw::X` scan below cannot see them. Hand-curated; each is consumed directly
# by its owning construct's tree and never becomes a graph node.
STRUCTURAL_EXTRA = {
    "ElsePart",                     # IfStmt.getElsePart(), SelectStmt.getElsePart()
    "ThenAbortPart",                # SelectStmt.getThenAbortPart()
    "NamedStmtDecl",                # NamedStmt.getDecl(), for the loop/block name
    "LabelDecl",                    # Label.getDecl(), for the label name
    "ExtendedReturnStmtObjectDecl",  # ExtendedReturnStmt.getDecl()
}

VERDICTS = [
    ("scope", "A CFG scope: gets its own disconnected graph with an entry and an exit. "
              "See Part 1, Scopes."),
    ("shaped", "Has a dedicated control-flow tree: its successor structure is "
               "specified in Part 3 and pinned by a conformance test."),
    ("expression", "Reached by `GenericPostOrderTree`: children are evaluated left to "
                   "right, then the node itself. No construct-specific shape."),
    ("opaque", "A statement with no dedicated tree, so `OpaqueStmtTree` makes it a leaf "
               "that completes normally. It is in the graph; its internals are not "
               "modelled (D-013)."),
    ("structural", "Read by the CFG but never becoming a node: its owning construct's "
                   "tree consumes it directly. Making these nodes would leak spurious "
                   "reachable elements into the graph -- see Part 1."),
    ("n/a", "Not control-relevant: nothing here is executed, so nothing is in the "
            "graph."),
]

# Why each family of non-control-relevant node is not in the graph. Order
# matters: the first matching rule wins.
NA_GROUPS = [
    ("operators",
     "Operator tokens. An operator is not itself executed -- its operands are, and the "
     "enclosing `BinOp`/`UnOp` node represents applying it. `exprLike` excludes "
     "`Raw::Op` for exactly this reason.",
     lambda n, a: n.startswith("Op") or "Op" in a),
    ("presence markers",
     "Generated `...Absent`/`...Present` pairs recording whether an optional keyword "
     "(`abstract`, `limited`, `overriding`, …) was written. Pure syntax.",
     lambda n, a: n.endswith("Absent") or n.endswith("Present")),
    ("type definitions and constraints",
     "The static type system: type definitions, subtype indications, constraints, "
     "ranges used as type bounds. Elaborating a type declaration can in principle run "
     "code (a dynamic bound, say), which the CFG does not model -- a documented "
     "limitation.",
     lambda n, a: ("TypeDef" in a or "BaseTypeDecl" in a or "Constraint" in a
                   or n.endswith("Constraint") or n.endswith("Def"))),
    ("declarations",
     "Declarations other than the object declarations whose initialisers are elaborated "
     "in a `declare` block or a body. The declarative part of a nested *package* is "
     "still not elaborated -- see Blocks.",
     lambda n, a: "BasicDecl" in a),
    ("lists",
     "List wrappers whose elements the owning construct reads directly. `StmtList` and "
     "`AssocList` are the exceptions and appear above.",
     lambda n, a: "AdaList" in a),
    ("abstract base classes",
     "Not instantiable: no node in a database has this kind.",
     lambda n, a: None),  # filled in from the schema's `concrete` flag
    ("other syntax",
     "Compilation units, with/use clauses, aspects, pragmas, defining names, "
     "designators and similar structure that carries no control flow.",
     lambda n, a: True),
]


def load_nodes():
    with io.open(SCHEMA, encoding="utf-8") as f:
        nodes = json.load(f)["nodes"]
    return {n["name"]: n for n in nodes}


def ancestors(ns, name):
    out, cur = [], name
    while cur in ns and ns[cur].get("base"):
        cur = ns[cur]["base"]
        out.append(cur)
    return out


def classify(ns, impl):
    """Assigns every node kind a verdict, deriving the rules from the impl."""
    shaped = set(re.findall(
        r"class\s+\w+\s+extends\s+[\w:]+\s+instanceof\s+Raw::(\w+)", impl)) - CATCH_ALL
    mentioned = set(re.findall(r"Raw::(\w+)", impl))

    # the CfgScope characteristic predicate lists the scope kinds
    charpred = re.search(r"CfgScope\(\)\s*\{(.*?)\}", impl, re.S)
    scopes = set(re.findall(r"Raw::(\w+)", charpred.group(1))) if charpred else set()

    # kinds GenericPostOrderTree explicitly declines: they either have their own
    # tree or are structural, so they are not plain post-order expressions
    gpo = re.search(r"GenericPostOrderTree\(\)\s*\{(.*?)\n  \}", impl, re.S)
    not_expr = set(re.findall(r"not this instanceof Raw::(\w+)", gpo.group(1))) if gpo else set()

    verdict = {}
    for name, node in ns.items():
        anc = ancestors(ns, name)
        concrete = node["concrete"]
        is_op = name.startswith("Op") or "Op" in anc
        if name in scopes:
            verdict[name] = "scope"
        elif name in shaped:
            verdict[name] = "shaped"
        elif concrete and not is_op and name not in not_expr and (
                "Expr" in anc or name == "AssocList" or "BasicAssoc" in anc):
            verdict[name] = "expression"
        elif concrete and "Stmt" in anc:
            verdict[name] = "opaque"
        elif name in STRUCTURAL_EXTRA or (concrete and name in not_expr):
            verdict[name] = "structural"
        elif not concrete or is_op:
            # abstract bases and operator tokens are never graph nodes, however
            # often the implementation names them
            verdict[name] = "n/a"
        elif name in mentioned:
            verdict[name] = "structural"
        else:
            verdict[name] = "n/a"
    return verdict


def na_group(ns, name):
    anc = ancestors(ns, name)
    if not ns[name]["concrete"]:
        return "abstract base classes"
    for label, _, rule in NA_GROUPS:
        if label == "abstract base classes":
            continue
        if rule(name, anc):
            return label
    return "other syntax"


def render(ns, verdict):
    lines = [BEGIN, ""]
    lines.append(f"All **{len(ns)}** node kinds in `schema/lal-nodes.json` are accounted "
                 "for below. This section is generated by")
    lines.append("`scripts/check_cfg_coverage.py`, which derives each verdict from "
                 "`ControlFlowGraphImpl.qll`;")
    lines.append("edit the implementation, then re-run it with `--write`. CI runs it "
                 "without `--write` and fails")
    lines.append("if a node kind is unaccounted for or the text below has drifted.")
    lines.append("")

    for label, blurb in VERDICTS:
        members = sorted(n for n, v in verdict.items() if v == label)
        lines.append(f"### {label} ({len(members)})")
        lines.append("")
        lines.append(blurb)
        lines.append("")
        if label == "n/a":
            groups = {}
            for n in members:
                groups.setdefault(na_group(ns, n), []).append(n)
            for glabel, gblurb, _ in NA_GROUPS:
                if glabel not in groups:
                    continue
                g = sorted(groups[glabel])
                lines.append(f"**{glabel}** ({len(g)}) — {gblurb}")
                lines.append("")
                lines.append(", ".join(f"`{n}`" for n in g))
                lines.append("")
        else:
            lines.append(", ".join(f"`{n}`" for n in members))
            lines.append("")

    lines.append(END)
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="regenerate the appendix")
    args = ap.parse_args()

    ns = load_nodes()
    with io.open(IMPL, encoding="utf-8") as f:
        impl = f.read()
    verdict = classify(ns, impl)

    missing = [n for n in ns if n not in verdict]
    if missing:
        print(f"error: {len(missing)} node kind(s) have no verdict: {missing[:10]}")
        return 1

    with io.open(DOC, encoding="utf-8") as f:
        doc = f.read()
    if BEGIN not in doc or END not in doc:
        print(f"error: {DOC} has no generated-coverage markers")
        return 1

    new = render(ns, verdict)
    start, end = doc.index(BEGIN), doc.index(END) + len(END)
    if doc[start:end] == new:
        counts = {}
        for v in verdict.values():
            counts[v] = counts.get(v, 0) + 1
        print("CFG coverage appendix is up to date: " +
              ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
        return 0

    if not args.write:
        print("error: the CFG coverage appendix in docs/cfg-design.md is out of date.")
        print("       Re-run: python scripts/check_cfg_coverage.py --write")
        return 1

    with io.open(DOC, "w", encoding="utf-8", newline="\n") as f:
        f.write(doc[:start] + new + doc[end:])
    print("wrote the CFG coverage appendix")
    return 0


if __name__ == "__main__":
    sys.exit(main())
