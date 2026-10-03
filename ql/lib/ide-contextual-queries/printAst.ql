/**
 * @name Print AST
 * @description Produces a representation of a file's Abstract Syntax Tree.
 *              This query is used by the VS Code extension's "View AST" command.
 * @id ada/print-ast
 * @kind graph
 * @tags ide-contextual-queries/print-ast
 */

private import ada
private import codeql.ada.PrintAst

/** Gets the source file selected in the IDE, as a source-archive path. */
external string selectedSourceFile();

/**
 * Holds if `f` is the file the IDE names `name`. The extension gives the
 * source-archive path: colons replaced by underscores, a leading slash even on
 * Windows. Same normalisation as `codeql/util`'s `IdeContextual`, whose `FileSig`
 * `Raw::File` does not implement.
 */
private predicate isSelectedFile(Raw::File f, string name) {
  name = ("/" + f.getAbsolutePath().replaceAll(":", "_")).replaceAll("//", "/")
}

private class PrintedNode extends Raw::AdaNode {
  PrintedNode() { isSelectedFile(fileOf(this), selectedSourceFile()) }
}

query predicate nodes(PrintedNode n, string key, string value) {
  key = "semmle.label" and value = nodeLabel(n)
  or
  key = "semmle.order" and
  not exists(n.getParent()) and
  exists(int i |
    n = rank[i](PrintedNode r | not exists(r.getParent()) | r order by preorderKey(r)) and
    value = i.toString()
  )
}

query predicate edges(PrintedNode parent, PrintedNode child, string key, string value) {
  parent = child.getParent() and
  (
    key = "semmle.label" and value = edgeLabel(child)
    or
    key = "semmle.order" and value = child.getParentIndex().toString()
  )
}

query predicate graphProperties(string key, string value) {
  key = "semmle.graphKind" and value = "tree"
}
