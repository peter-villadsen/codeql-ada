/**
 * @name Unused parameter
 * @description A parameter that is never read or written in the body of a subprogram is
 *              either dead code or a sign that the wrong name was used inside the body.
 *              Not reported: overriding bodies, parameters marked by `pragma
 *              Unreferenced` or `with Unreferenced`, and parameters whose name appears,
 *              unresolved, in the body (a reference extraction could not resolve,
 *              usually a missing dependency; D-026).
 * @id ada/unused-parameter
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

/**
 * Gets the `i`th formal parameter declared by `spec`.
 */
private ParamSpec getParam(SubpSpec spec, int i) {
  result = spec.getSubpParams().getParams().getChild(i)
}

from SubpBody body, SubpSpec spec, ParamSpec param, int i
where
  spec = body.getSubpSpec() and
  param = getParam(spec, i) and
  // A reference inside a body always resolves to that body's own `ParamSpec`, never to a
  // separate forward declaration's copy, even when one exists (confirmed by inspecting
  // `ada_xref` on a spec+body test case) - so no decl/body pairing is needed here, unlike
  // `ada/dead-local-subprogram` and `ada/direct-recursion`, where *calls* do resolve to the
  // separate declaration when present.
  not param.isReferenced() and
  // `pragma Unreferenced (X)` or `X : T with Unreferenced`.
  not param.isMarkedUnreferenced() and
  // GNAT's rule: `Dummy`, `Ignore`, `Unused_...` are unused on purpose
  not param.hasJunkName() and
  // a callback (`'Access`) or generic actual cannot choose its own parameters
  not exists(Subprogram s | s.getBody() = body and s.hasImposedProfile()) and
  // A same-named name that did not resolve may be a use (missing dependencies, D-026).
  not param.hasUnresolvedNamesakeIn(body) and
  not body.getOverriding() instanceof OverridingOverriding and
  param.fromSource()
select param, "This parameter is never used in this body."
