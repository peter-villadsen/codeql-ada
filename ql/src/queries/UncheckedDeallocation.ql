/**
 * @name Use of Unchecked_Deallocation
 * @description Instantiations of Ada.Unchecked_Deallocation free heap memory without
 *              compiler-checked lifetime tracking, risking dangling pointers and
 *              double-free if a freed access value is used or deallocated again.
 * @id ada/unchecked-deallocation
 * @kind table
 * @tags security correctness
 */

import ada

from Raw::GenericSubpInstantiation gi
where
  gi.getGenericSubpName().(Name).getText().toLowerCase().matches("%unchecked_deallocation")
select gi, "Instantiation of Unchecked_Deallocation risks dangling pointers or double-free."
