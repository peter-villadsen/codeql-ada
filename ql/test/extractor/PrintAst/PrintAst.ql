/**
 * @name AST dump (golden extractor regression test)
 * @description Dumps every project AST node's kind and its parent/index in
 *              the tree (predefined pseudo-sources are PrintPredefined's job). Not a security query — a regression guard on the
 *              extractor/dbscheme pipeline itself (Phase 5.2): a change that
 *              silently drops nodes, breaks parent-child linking, or renames a
 *              QL class shows up here even if no security query happens to
 *              touch the affected relation.
 * @id ada/test/print-ast
 * @kind table
 */

import ada

from Raw::AdaNode n
where n.(AdaNode).fromSource()
select n, n.getAPrimaryQlClass(), n.getParent(), n.getParentIndex()
