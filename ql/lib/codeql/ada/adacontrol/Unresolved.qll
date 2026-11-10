/**
 * Identifiers that did not resolve, for the AdaControl-parity rules that count
 * references: an identifier spelled like a declaration may be a reference that
 * extraction could not resolve, typically because a dependency of the project was not
 * available (D-026: fall back to text only when a name does not resolve).
 */

private import codeql.ada.ast.internal.Raw

module Unresolved {
  /**
   * Holds if identifier `i`, spelled `lname` in lower case, did not resolve, and is not
   * a defining name, an end name, or the name of an attribute, pragma or aspect.
   */
  predicate identifier(Raw::Identifier i, string lname) {
    not exists(i.getReferencedDecl()) and
    lname = i.getValue().toLowerCase() and
    not i.getParent() instanceof Raw::DefiningName and
    not i.getParent+() instanceof Raw::EndName and
    not i = any(Raw::AttributeRef a).getAttribute() and
    not i = any(Raw::PragmaNode p).getId() and
    not i = any(Raw::AspectAssoc a).getId()
  }
}
