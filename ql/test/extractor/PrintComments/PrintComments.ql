/**
 * @name Comment dump (golden extractor regression test)
 * @description Dumps every extracted comment's text. Comments are trivia, not
 *              part of the AST tree, so PrintAst.ql doesn't exercise this path;
 *              this is a regression guard on the extractor's separate token-walk
 *              (`emit_comments`) that populates `ada_comments`.
 * @id ada/test/print-comments
 * @kind table
 */

import ada

from Raw::Comment c
select c, c.getText()
