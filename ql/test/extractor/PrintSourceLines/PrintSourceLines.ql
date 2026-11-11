/**
 * @name Source line dump (golden extractor regression test)
 * @description Dumps every extracted source line: its number, length, whether it is
 *              blank, and its text with tabs shown as `<TAB>`. A regression guard on
 *              the extractor's `emit_lines`, which populates `ada_source_lines`: a CR LF
 *              terminator is removed like an LF one, and a last line without terminator
 *              counts.
 * @id ada/test/print-source-lines
 * @kind table
 */

import ada

from SourceLine l
select l, l.getLineNumber(), l.getLength(),
  any(string b | if l.isBlank() then b = "blank" else b = ""),
  "[" + l.getText().replaceAll("\t", "<TAB>") + "]"
