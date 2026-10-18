#!/usr/bin/env python3
"""Check (or regenerate) the CFG coverage appendix in docs/cfg-design.md.

Every node kind in ``schema/lal-nodes.json`` must carry an explicit verdict
saying how the control-flow graph treats it, so that a future grammar addition
cannot silently slip past the CFG (decision D-016).

The verdicts are *derived from the implementation*, not maintained by hand:
this script reads ``ControlFlowGraphImpl.qll`` to find which node kinds it gives
a rule of their own (children in ``getChild0``, a class of the shared library's
AST signature, or steps), which are evaluated by the library's default rule
(expressions; statements, as leaves), and which it merely reads without ever
turning into a node. Whatever is left is not control-relevant, and is grouped by
why.

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
# Where the AST facts the graph is built from start (calls that may raise, jump
# targets): the node kinds named after this marker are inspected, not shaped.
HELPERS_MARKER = "// AST facts the graph is built from"

# Node kinds the implementation reads but never makes nodes of: their parts are
# children of the construct that owns them. Each maps to the text by which the
# implementation reaches it (its `Raw::` name or an accessor); that text must occur
# in the implementation (checked), so that a stale entry is noticed.
STRUCTURAL = {
    "DeclarativePart": "Raw::DeclarativePart",        # a body's or block's: its initialisers are children
    "ObjectDecl": "Raw::ObjectDecl",                  # its initialiser is a child; the declaration is not
    "ElsePart": "getElsePart()",                      # IfStmt / SelectStmt: the statements are the child
    "ThenAbortPart": "getThenAbortPart()",            # select ... then abort: the statements are the child
    "SelectWhenPart": "Raw::SelectWhenPart",          # a select alternative: its statements are the child
    "FinallyPart": "getFinallyPart()",                # HandledStmts: the statements are the child
    "WhileLoopSpec": "Raw::WhileLoopSpec",            # the condition is the loop's child
    "ForLoopSpec": "Raw::ForLoopSpec",                # the iterable and the variable are the loop's children
    "ForLoopVarDecl": "getVarDecl()",                 # its defining name is the loop's child
    "RangeConstraint": "Raw::RangeConstraint",        # `for I in T range A .. B`: the range is the child
    "ExtendedReturnStmtObjectDecl": "getDecl().getDefaultExpr()",  # its initialiser is the return's child
    "ParamSpec": "Raw::ParamSpec",                    # its default is a body part (formalDefault)
    "NamedStmtDecl": "Raw::NamedStmt",                # NamedStmt.getDecl(), for the loop's name
    "LabelDecl": "Raw::Label",                        # Label.getDecl(), for the label's name
    "OthersDesignator": "Raw::OthersDesignator",      # a choice: its AlternativesList is the node
}

# Kinds `exprLike` names: evaluated by the default rule, not shaped.
EXPR_LIKE_BLOCK = re.compile(r"private predicate exprLike\(.*?\n\}", re.S)

VERDICTS = [
    ("scope", "A CFG scope: gets its own disconnected graph with an entry and an exit. "
              "See Part 1, Scopes."),
    ("shaped", "Has a rule of its own in `ControlFlowGraphImpl.qll` (its evaluated "
               "children, a class of the library's AST signature, or steps): its "
               "successor structure is specified in Part 3 and pinned by a conformance "
               "test."),
    ("expression", "Evaluated by the library's default rule: its evaluated children "
                   "left to right, then the node itself. No construct-specific shape."),
    ("opaque", "A statement with no rule of its own: a leaf that completes normally. It "
               "is in the graph; its internals are not modelled (D-013)."),
    ("structural", "Read by the CFG but never a node: its parts are children of the "
                   "construct that owns it (`getChild0`). See Part 1."),
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
    graph = impl.split(HELPERS_MARKER)[0]

    # the CfgScope characteristic predicate lists the scope kinds
    charpred = re.search(r"CfgScope\(\)\s*\{(.*?)\}", graph, re.S)
    scopes = set(re.findall(r"Raw::(\w+)", charpred.group(1))) if charpred else set()

    expr_like = EXPR_LIKE_BLOCK.search(graph)
    # the kinds `exprLike` lists (its parameter is typed `Raw::AdaNode`, not a kind)
    expr_kinds = set(re.findall(r"Raw::(\w+)", expr_like.group(0))) - {"AdaNode"} if expr_like else set()
    rest = EXPR_LIKE_BLOCK.sub("", graph)
    if charpred:
        rest = rest.replace(charpred.group(0), "")
    mentioned = set(re.findall(r"Raw::(\w+)", rest))

    stale = [k for k, how in STRUCTURAL.items() if how not in impl]
    if stale:
        raise SystemExit(f"error: STRUCTURAL names kinds the implementation no longer reads: {sorted(stale)}")

    verdict = {}
    for name, node in ns.items():
        anc = ancestors(ns, name)
        concrete = node["concrete"]
        is_op = name.startswith("Op") or "Op" in anc
        if not concrete or is_op:
            # abstract bases and operator tokens are never graph nodes, however
            # often the implementation names them
            verdict[name] = "n/a"
        elif name in scopes:
            verdict[name] = "scope"
        elif name in STRUCTURAL:
            verdict[name] = "structural"
        elif name in mentioned:
            verdict[name] = "shaped"
        elif name in expr_kinds or "Expr" in anc or "BasicAssoc" in anc:
            verdict[name] = "expression"
        elif "Stmt" in anc:
            verdict[name] = "opaque"
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
