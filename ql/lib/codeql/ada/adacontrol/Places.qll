/**
 * AdaControl's locations (`<location>` of `Declarations`, `Entities`, `Instantiations`,
 * `Renaming_Declarations`): where a declaration or a use is.
 *
 * - `library`: at library level, inside packages only (or the library unit itself);
 * - `local`: not at library level, inside a subprogram, task, entry or block;
 * - `block`: directly in the declarations of a block statement;
 * - `own`: directly in the declarations of a package body;
 * - `public`: directly in the visible part of a package spec;
 * - `private`: directly in the private part of a package spec;
 * - `in_generic`: anywhere in a generic unit, spec or body;
 * - `task_body`: directly in the declarations of a task body;
 * - `nested`: inside a subprogram, task or entry body, or a block (`Entities` only).
 */

private import codeql.ada.ast.internal.Raw

module Places {
  /** Holds if `n` is a body or block whose declarations are not at library level. */
  private predicate isLocalScope(Raw::AdaNode n) {
    n instanceof Raw::BaseSubpBody or
    n instanceof Raw::TaskBody or
    n instanceof Raw::EntryBody or
    n instanceof Raw::ProtectedBody or
    n instanceof Raw::BlockStmt or
    n instanceof Raw::AcceptStmt
  }

  /** Holds if `n` is at library level: no enclosing subprogram, task, entry, protected body or block. */
  predicate isLibraryLevel(Raw::AdaNode n) { not isLocalScope(n.getParent+()) }

  /** Gets the declarative part `d` is directly in, if any. */
  Raw::DeclarativePart declarativePart(Raw::AdaNode d) { d = result.getDecls().getChild(_) }

  /** Holds if `n` is inside a generic unit: its formal part, spec or body. */
  predicate inGeneric(Raw::AdaNode n) {
    n.getParent+() instanceof Raw::GenericDecl
    or
    exists(Raw::BasicDecl g, Raw::BodyNode body |
      body = n.getParent+() and
      (g instanceof Raw::GenericDecl or g.getParent() instanceof Raw::GenericDecl) and
      ada_body_part(g, body)
    )
  }

  /** Holds if declaration (or use) `n` is at `place`, one of the locations above. */
  predicate isAt(Raw::AdaNode n, string place) {
    place = "library" and isLibraryLevel(n)
    or
    place = "local" and not isLibraryLevel(n)
    or
    place = "nested" and not isLibraryLevel(n)
    or
    place = "block" and declarativePart(n).getParent() instanceof Raw::DeclBlock
    or
    place = "own" and declarativePart(n).getParent() instanceof Raw::PackageBody
    or
    place = "public" and
    declarativePart(n) instanceof Raw::PublicPart and
    declarativePart(n).getParent() instanceof Raw::BasePackageDecl
    or
    place = "private" and
    declarativePart(n) instanceof Raw::PrivatePart and
    declarativePart(n).getParent() instanceof Raw::BasePackageDecl
    or
    place = "in_generic" and inGeneric(n)
    or
    place = "task_body" and declarativePart(n).getParent() instanceof Raw::TaskBody
  }
}
