/**
 * Printing the AST: what tree the extractor produced for some Ada source, in the
 * terms a query uses. Each node is shown with its `Raw` class, its token text (an
 * identifier's name, a literal's value), and, for a name, the qualified name of the
 * declaration it resolves to; each edge with the accessor that reaches the child
 * (`getSuffix`, `getName`, ...) or, for a list element, its index.
 *
 * Used by `ide-contextual-queries/printAst.ql` (VS Code's "View AST") and
 * `tools/PrintAst.ql` (an indented text tree from the command line). See
 * `docs/ast-reference.md` for the common shapes.
 */

private import ada
private import codeql.ada.ast.internal.RawMeta

/** Gets the label of `n`: its class, then its token text and resolution, if any. */
string nodeLabel(Raw::AdaNode n) {
  exists(string text, string target |
    (if exists(tokenText(n)) then text = " " + tokenText(n) else text = "") and
    (
      if exists(n.(Name).getReferencedDecl().(BasicDecl).getQualifiedName())
      then
        target =
          " -> " +
            concat(n.(Name).getReferencedDecl().(BasicDecl).getQualifiedName(), " | ")
      else target = ""
    ) and
    result = n.getAPrimaryQlClass() + text + target
  )
}

/**
 * Gets the label of the edge from `n`'s parent to `n`: the `Raw` accessor that
 * reaches it, or `[i]` for the `i`th element of a list (`getChild(i)`).
 */
string edgeLabel(Raw::AdaNode n) {
  exists(n.getParent()) and
  (
    if childAccessor(n.getParent(), n, _)
    then result = concat(string a | childAccessor(n.getParent(), n, a) | a, "/")
    else result = "[" + n.getParentIndex() + "]"
  )
}

/** Gets `i` zero-padded to six digits, so that keys sort numerically as strings. */
bindingset[i]
private string pad(int i) { result = "000000".prefix(6 - i.toString().length()) + i.toString() }

/**
 * Gets a key that sorts `n` into pre-order within its file: a root (a compilation
 * unit) by its position, every other node after its parent and by its index.
 */
string preorderKey(Raw::AdaNode n) {
  not exists(n.getParent()) and
  result = pad(n.getLocation().getStartLine()) + ":" + pad(n.getLocation().getStartColumn())
  or
  result = preorderKey(n.getParent()) + "." + pad(n.getParentIndex())
}

/** Gets the depth of `n` in its tree: 0 for a compilation unit. */
int depth(Raw::AdaNode n) {
  not exists(n.getParent()) and result = 0
  or
  result = depth(n.getParent()) + 1
}

/** Gets the file `n` is in. */
Raw::File fileOf(Raw::AdaNode n) { locations_default(n.getLocation(), result, _, _, _, _) }
