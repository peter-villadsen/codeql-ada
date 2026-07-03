/**
 * @name Use of Unchecked_Conversion
 * @description Instantiations of Ada.Unchecked_Conversion reinterpret raw bits
 *              between types, bypassing type safety; each use deserves review.
 * @id ada/unchecked-conversion
 * @kind table
 * @tags security correctness
 */

import ada

from Raw::GenericSubpInstantiation gi
where
  gi.getGenericSubpName().(Name).getText().toLowerCase().matches("%unchecked_conversion")
select gi, "Instantiation of Unchecked_Conversion bypasses type safety."
