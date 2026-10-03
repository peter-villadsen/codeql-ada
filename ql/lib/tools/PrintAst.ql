/**
 * @name Print AST as text
 * @description Prints the AST of every project file (not the predefined
 *              pseudo-sources) as an indented tree, in the terms a query uses: each
 *              line is `accessor: Class token -> resolved declaration`. Meant for a
 *              small scratch database built from the Ada you want to look at; see
 *              `docs/ast-reference.md`.
 * @id ada/tools/print-ast-text
 * @kind table
 */

import ada
import codeql.ada.PrintAst

/** Gets `n`'s line as indented text: two spaces per level, the edge label, the node label. */
string treeLine(Raw::AdaNode n) {
  exists(string indent, string edge |
    indent = concat(int i | i in [1 .. depth(n)] | "  " order by i) and
    (if exists(edgeLabel(n)) then edge = edgeLabel(n) + ": " else edge = "") and
    result = indent + edge + nodeLabel(n)
  )
}

from Raw::AdaNode n, string file, int row
where
  n.(AdaNode).fromSource() and
  file = fileOf(n).getAbsolutePath().regexpCapture(".*/([^/]*)", 1) and
  n =
    rank[row](Raw::AdaNode m |
      m.(AdaNode).fromSource() and fileOf(m) = fileOf(n)
    |
      m order by preorderKey(m)
    )
select file, row, n.getLocation().getStartLine() + ":" + n.getLocation().getStartColumn() as pos,
  treeLine(n) as tree order by file, row
