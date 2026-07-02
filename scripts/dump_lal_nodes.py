"""Spike 1.3: dump Libadalang's node-kind hierarchy via Python introspection.

Produces a JSON description of every AST node class (name, base class,
abstractness, token-node-ness, and syntax fields) — the raw input for
generating the dbscheme, TRAP emitter, and QL AST classes (decision D-004).

Run inside the environment set up by build-libadalang.sh:
  source ~/lal-venv/bin/activate
  eval "$(cd ~/src/libadalang && python -m langkit.scripts.lkm printenv)"
  python dump_lal_nodes.py > lal-nodes.json
"""

import json
import sys

import libadalang as lal


def node_classes():
    """All classes in the AdaNode hierarchy, including AdaNode itself."""
    seen = {}

    def walk(cls):
        if cls.__name__ in seen:
            return
        seen[cls.__name__] = cls
        for sub in cls.__subclasses__():
            walk(sub)

    walk(lal.AdaNode)
    return seen


def describe(cls) -> dict:
    is_abstract = bool(cls.__subclasses__())  # heuristic; refined below
    kind_name = getattr(cls, "_kind_name", None)
    # Concrete Langkit-generated classes carry a _kind_name; abstract ones don't.
    concrete = kind_name is not None

    fields = []
    for name in dir(cls):
        if not name.startswith("f_"):
            continue
        # Only count fields introduced by this class, not inherited ones.
        if not any(name in base.__dict__ for base in cls.__mro__[1:]):
            fields.append(name)

    return {
        "name": cls.__name__,
        "base": cls.__mro__[1].__name__,
        "concrete": concrete,
        "kind_name": kind_name,
        "abstract_heuristic": is_abstract,
        "is_list_node": issubclass(cls, lal.AdaList) and cls is not lal.AdaList,
        "is_token_node": bool(getattr(cls, "_token_node", False)),
        "fields": sorted(fields),
    }


def main() -> int:
    classes = node_classes()
    out = {
        "libadalang_version": getattr(lal, "version", "unknown"),
        "node_count": len(classes),
        "concrete_count": sum(
            1 for c in classes.values() if getattr(c, "_kind_name", None)
        ),
        "nodes": sorted(
            (describe(c) for c in classes.values()), key=lambda d: d["name"]
        ),
    }
    json.dump(out, sys.stdout, indent=2)
    print()
    print(
        f"[dump_lal_nodes] {out['node_count']} classes, "
        f"{out['concrete_count']} concrete",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
