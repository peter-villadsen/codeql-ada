/**
 * @name Print SSA-renamed source edits
 * @description Emits a flat edit list -- (file, line, startCol, endCol,
 *              text, kind) -- for rendering a source file with SSA names
 *              made explicit: `kind = "substitute"` rows replace the span
 *              [startCol, endCol) on that line with `text` (the SSA name);
 *              `kind = "comment"` rows (startCol/endCol both -1) append
 *              ` -- text` at the end of the line, for a phi node.
 *              See docs/ssa-design.md, "Renamed-source rendering", and
 *              scripts/render_ssa.py, which applies this to a copy of the
 *              source.
 * @kind table
 * @id ada/debug/ssa-renamed
 */

import codeql.ada.test.SsaRenderAnnotations

from string file, int line, int startCol, int endCol, string text, string kind
where
  (writeEdit(file, line, startCol, endCol, text) and kind = "substitute")
  or
  (readEdit(file, line, startCol, endCol, text) and kind = "substitute")
  or
  (commentEdit(file, line, text) and kind = "comment" and startCol = -1 and endCol = -1)
select file, line, startCol, endCol, text, kind order by file, line, startCol desc
