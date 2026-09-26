/**
 * @name Unused parameter
 * @description A parameter that is never read or written in the body of a subprogram is
 *              either dead code or a sign that the wrong name was used inside the body.
 * @id ada/unused-parameter
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

/**
 * Gets the `i`th formal parameter declared by `spec`.
 */
private Raw::ParamSpec getParam(Raw::SubpSpec spec, int i) {
  result = spec.getSubpParams().getParams().getChild(i)
}

/**
 * Holds if a `pragma Unreferenced` inside `body` names `param`.
 */
private predicate hasUnreferencedPragma(Raw::SubpBody body, Raw::ParamSpec param) {
  exists(Raw::PragmaNode p, Raw::PragmaArgumentAssoc a, Raw::DefiningName id |
    p.getParent+() = body and
    p.getId().getValue().toLowerCase() = "unreferenced" and
    a = p.getArgs().getChild(_) and
    a.getExpr().(Raw::Identifier).getValue().toLowerCase() =
      id.getName().(Name).getText().toLowerCase() and
    id = param.getIds().getChild(_)
  )
}

from Raw::SubpBody body, Raw::SubpSpec spec, Raw::ParamSpec param, int i
where
  spec = body.getSubpSpec() and
  param = getParam(spec, i) and
  // A reference inside a body always resolves to that body's own `ParamSpec`, never to a
  // separate forward declaration's copy, even when one exists (confirmed by inspecting
  // `ada_xref` on a spec+body test case) - so no decl/body pairing is needed here, unlike
  // `ada/dead-local-subprogram` and `ada/direct-recursion`, where *calls* do resolve to the
  // separate declaration when present.
  not param.(BasicDecl).isReferenced() and
  not hasUnreferencedPragma(body, param) and
  not body.getOverriding() instanceof Raw::OverridingOverriding and
  param.(AdaNode).fromSource()
select param, "This parameter is never used in this body."
