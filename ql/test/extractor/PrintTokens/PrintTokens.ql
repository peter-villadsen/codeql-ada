/**
 * @name Token dump (golden extractor regression test)
 * @description Dumps every extracted token: its index, kind and text. A regression
 *              guard on the extractor's token walk (`emit_tokens`) that populates
 *              `ada_tokens`.
 * @id ada/test/print-tokens
 * @kind table
 */

import ada

from Token t
select t, t.getIndex(), t.getKind(), t.getText(),
  concat(Token n | n = t.getNext() | n.getText())
