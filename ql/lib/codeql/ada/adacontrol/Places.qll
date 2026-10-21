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
 *
 * `isAt` is where a declaration is; `useIsAt` is where a use of an entity is, as
 * `Entities` means it (in a block at any depth, in a package body, ...).
 */

private import codeql.ada.ast.internal.Raw

module Places {
  /** Holds if `n` is a body or block whose declarations are not at library level. */
  private predicate isLocalScope(Raw::AdaNode n) {
    // a renaming declares nothing inside it
    n instanceof Raw::BaseSubpBody and not n instanceof Raw::SubpRenamingDecl
    or
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

  /** Holds if `n` is a unit-like construct: a package spec or body, a subprogram, task, entry or protected body. */
  private predicate isUnitLike(Raw::AdaNode n) {
    n instanceof Raw::BasePackageDecl or
    n instanceof Raw::PackageBody or
    isLocalScope(n) and not n instanceof Raw::BlockStmt
  }

  /** Gets the innermost unit-like construct around `n`. */
  private Raw::AdaNode innermostUnit(Raw::AdaNode n) {
    result = n.getParent+() and
    isUnitLike(result) and
    not exists(Raw::AdaNode inner | inner = n.getParent+() and isUnitLike(inner) and inner.getParent+() = result)
  }

  /** Gets the innermost declarative part around `n`. */
  private Raw::DeclarativePart innermostDeclarativePart(Raw::AdaNode n) {
    result = n.getParent+() and
    not exists(Raw::DeclarativePart inner | inner = n.getParent+() and inner.getParent+() = result)
  }

  /** Holds if a use `n` of an entity appears at `place` (AdaControl's `Entities` locations). */
  predicate useIsAt(Raw::AdaNode n, string place) {
    place = "block" and n.getParent+() instanceof Raw::BlockStmt
    or
    place = "library" and isLibraryLevel(n)
    or
    place = ["local", "nested"] and not isLibraryLevel(n)
    or
    place = "own" and innermostUnit(n) instanceof Raw::PackageBody
    or
    place = "public" and
    innermostDeclarativePart(n) instanceof Raw::PublicPart and
    innermostDeclarativePart(n).getParent() = innermostUnit(n)
    or
    place = "private" and
    innermostDeclarativePart(n) instanceof Raw::PrivatePart and
    innermostDeclarativePart(n).getParent() = innermostUnit(n)
    or
    place = "in_generic" and inGeneric(n)
    or
    place = "task_body" and innermostUnit(n) instanceof Raw::TaskBody
  }
}
