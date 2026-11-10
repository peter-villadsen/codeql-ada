/**
 * @name Use of a type through an attribute or as an index
 * @description Some uses of a type are worth checking in a project: an attribute
 *              whose result depends on the representation (`'Size`, `'Pos` of an
 *              enumeration with a representation clause), or an enumeration or modular
 *              type used to index arrays. AdaControl rule `Type_Usage`, for the uses
 *              named with the data extension `typeUsage` (usage, type or category,
 *              aspect condition). With no row, nothing is reported. Left out: the `<>`
 *              category. See `codeql.ada.adacontrol.TypeUsage` (`docs/adacontrol.md`).
 * @id ada/type-usage
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.TypeUsage
import codeql.ada.adacontrol.Settings

from AdaNode site, Type t, string usage, string type, string aspect, string msg
where
  site.fromSource() and
  typeUsage(usage, type, aspect) and
  TypeUsage::matches(t, type) and
  TypeUsage::satisfies(t, aspect) and
  (
    exists(string attribute |
      TypeUsage::attributeUse(site, t, attribute) and
      usage.toLowerCase() = ["'" + attribute, attribute] and
      msg = "Attribute '" + site.(Raw::AttributeRef).getAttribute().getValue() + " of type " + t.getName() + "."
    )
    or
    exists(Type array |
      TypeUsage::indexUse(array, site, t) and
      usage.toLowerCase() = "index" and
      msg = "Type " + t.getName() + " is an index of array type " + array.getName() + "."
    )
  )
select site, msg
