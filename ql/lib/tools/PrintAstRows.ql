/**
 * @name Print AST as rows
 * @description The AST of every project file (not the predefined pseudo-sources),
 *              one row per node in pre-order, with the node's depth, edge label,
 *              class, token text, resolution target and position as separate
 *              columns. The input of `scripts/print_ast.py`, which rebuilds the tree
 *              as text, JSON or XML; `tools/PrintAst.ql` is the same tree as text.
 *              The external predicate `selectedFile` must be supplied
 *              (`--external=selectedFile=<csv>`): a CSV of path suffixes such as
 *              `adasat-formulas.adb` or `src/adasat-formulas.adb`; an empty file
 *              prints every file.
 * @id ada/tools/print-ast-rows
 * @kind table
 */

import ada
import codeql.ada.PrintAst

/** Gets a path suffix naming a file to print. Every project file when there is none. */
external string selectedFile();

/** Holds if `f` is a file to print. */
predicate isPrinted(Raw::File f) {
  not exists(selectedFile())
  or
  exists(string sel, string path | sel = selectedFile() and path = f.getAbsolutePath() |
    path = sel or path.matches("%/" + sel)
  )
}

from Raw::AdaNode n, Raw::File file, int row, Location loc
where
  n.(AdaNode).fromSource() and
  file = fileOf(n) and
  isPrinted(file) and
  n = rank[row](Raw::AdaNode m | m.(AdaNode).fromSource() and fileOf(m) = file | m order by preorderKey(m)) and
  loc = n.getLocation()
select file.getAbsolutePath() as path, row, depth(n) as depth,
  concat(edgeLabel(n)) as edge, n.getAPrimaryQlClass() as nodeClass, concat(nodeText(n)) as text,
  concat(string t | t = nodeTarget(n) | t, "\n") as targets, loc.getStartLine() as startLine,
  loc.getStartColumn() as startColumn, loc.getEndLine() as endLine,
  loc.getEndColumn() as endColumn order by path, row
