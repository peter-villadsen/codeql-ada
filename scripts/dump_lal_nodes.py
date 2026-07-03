"""Spike 1.3 / Phase 2 input: dump Libadalang's node hierarchy via introspection.

Produces a JSON description of every AST node class — name, base, abstractness,
list/token flags, and typed syntax fields (with nullability and declaration
order) — the input for generating the dbscheme, TRAP emitter tables, and QL AST
classes (decision D-004).

Run inside the WSL build environment:
  source ~/lal-venv/bin/activate
  export PYTHONPATH=~/adacore/python LD_LIBRARY_PATH=~/adacore/lib
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


def field_type_name(cls, fname: str) -> str:
    """Return type of a field property, from the generated annotations."""
    prop = getattr(cls, fname)
    fget = prop.fget
    ann = getattr(fget, "__annotations__", {}).get("return")
    if ann is None:
        return "AdaNode"
    if isinstance(ann, str):
        return ann.strip("'\"")
    return getattr(ann, "__name__", str(ann))


def describe(cls) -> dict:
    kind_name = getattr(cls, "_kind_name", None)
    # A field is "own" if the property object lives in this class's __dict__
    # (abstract classes declare fields their _field_names doesn't list).
    own_field_names = sorted(
        f for f, v in cls.__dict__.items()
        if f.startswith("f_") and isinstance(v, property)
    )
    fields = []
    for f in own_field_names:
        doc = (getattr(cls, f).fget.__doc__ or "")
        fields.append({
            "name": f,
            "type": field_type_name(cls, f),
            "nullable": "field is never null" not in doc,
        })

    return {
        "name": cls.__name__,
        "base": cls.__mro__[1].__name__,
        "concrete": kind_name is not None,
        "kind_name": kind_name,
        "is_list_node": issubclass(cls, lal.AdaList) and cls is not lal.AdaList,
        "is_token_node": bool(getattr(cls, "_token_node", False)),
        # Full field order (inherited + own) as the parser emits children.
        "all_field_order": [
            f for f in getattr(cls, "_field_names", ()) if f.startswith("f_")
        ],
        "fields": fields,
    }


def main() -> int:
    classes = node_classes()
    out = {
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
