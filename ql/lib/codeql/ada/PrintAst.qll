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

/**
 * Gets how declaration `d`, as the target of name `n`, is shown: the qualified name
 * of the defining name `n` denotes. A declaration of several names (`A, B : T`) has
 * one qualified name per name, so the one whose last component is spelled like `n`
 * is chosen; all of them when none is. A declaration with no qualified name shows
 * its class, names and position.
 */
private string declLabel(Raw::Name n, Raw::BasicDecl d) {
  d = n.(Name).getReferencedDecl() and
  if exists(d.(BasicDecl).getQualifiedName())
  then
    exists(string last | last = lastComponent(n) |
      if exists(string q | q = d.(BasicDecl).getQualifiedName() and endsWithName(q, last))
      then result = d.(BasicDecl).getQualifiedName() and endsWithName(result, last)
      else result = d.(BasicDecl).getQualifiedName()
    )
    or
    not exists(lastComponent(n)) and result = d.(BasicDecl).getQualifiedName()
  else
    result =
      d.getAPrimaryQlClass() + " " + concat(d.(BasicDecl).getAName(), ", ") + " @" +
        d.getLocation().getStartLine() + ":" + d.getLocation().getStartColumn()
}

/** Gets the text of `n`'s last component: a dotted name's suffix, else its own text. */
private string lastComponent(Raw::Name n) {
  result = n.(Raw::DottedName).getSuffix().(Name).getText()
  or
  not n instanceof Raw::DottedName and result = n.(Name).getText()
}

/** Holds if qualified name `q`'s last component is `last`, ignoring case. */
bindingset[q, last]
private predicate endsWithName(string q, string last) {
  exists(string ql, string ll | ql = q.toLowerCase() and ll = last.toLowerCase() |
    ql = ll or ql.suffix(ql.length() - ll.length() - 1) = "." + ll
  )
}

/** Gets the token text of `n`: an identifier's name, a literal's value, an operator's symbol. */
string nodeText(Raw::AdaNode n) { result = tokenText(n) }

/**
 * Gets a declaration name `n` resolves to, as `nodeLabel` shows it after `->`. Usually
 * one; a name whose declaration has several qualified names may have more.
 */
string nodeTarget(Raw::AdaNode n) { result = declLabel(n, _) }

/** Gets the label of `n`: its class, then its token text and resolution, if any. */
string nodeLabel(Raw::AdaNode n) {
  exists(string text, string target |
    (if exists(tokenText(n)) then text = " " + tokenText(n) else text = "") and
    (
      if exists(n.(Name).getReferencedDecl())
      then
        target =
          " -> " + concat(string s | s = declLabel(n, _) | s, " | ")
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
