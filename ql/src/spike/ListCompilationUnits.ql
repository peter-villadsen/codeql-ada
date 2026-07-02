/**
 * @name List compilation units
 * @description Pipeline proof: lists every compilation unit the extractor emitted.
 * @id ada/spike/list-compilation-units
 * @kind table
 */

import ada

from CompilationUnit unit
select unit.getName(), unit.getFile().getAbsolutePath()
