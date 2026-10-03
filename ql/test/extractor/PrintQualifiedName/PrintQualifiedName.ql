/**
 * @name Qualified names (extractor golden test)
 * @description Every project declaration's qualified name(s). A declaration of
 *              several names (`A, B : T`) has one per name.
 * @id ada/test/print-qualified-name
 * @kind table
 */

import ada

from BasicDecl d, string q
where d.(AdaNode).fromSource() and q = d.getQualifiedName()
select d, d.getAPrimaryQlClass(), q
