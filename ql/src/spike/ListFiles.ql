/**
 * @name List extracted files
 * @description Pipeline proof: lists every file the extractor emitted.
 * @id ada/spike/list-files
 * @kind table
 */

import ada

from File f
select f.getAbsolutePath()
