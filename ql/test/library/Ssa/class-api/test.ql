import ada
import codeql.ada.dataflow.Ssa

string kind(SsaDefinition def) {
  def instanceof SsaParameterInit and result = "param"
  or
  def instanceof SsaExplicitWrite and not def instanceof SsaParameterInit and result = "explicit"
  or
  def instanceof SsaUncertainWrite and result = "uncertain"
  or
  def instanceof SsaPhiDefinition and result = "phi"
  or
  def instanceof SsaImplicitWrite and not def instanceof SsaUncertainWrite and result = "implicit"
}

query predicate definitions(SsaDefinition def, string k, string defining, string value, string param) {
  k = kind(def) and
  (if exists(def.(SsaExplicitWrite).getDefiningExpr())
   then defining = def.(SsaExplicitWrite).getDefiningExpr().toString()
   else defining = "-") and
  (if exists(def.(SsaExplicitWrite).getValue())
   then value = def.(SsaExplicitWrite).getValue().toString()
   else value = "-") and
  (if exists(def.(SsaParameterInit).getParameter())
   then param = def.(SsaParameterInit).getParameter().getName()
   else param = "-")
}

query predicate reads(SsaDefinition def, Expr read) { read = def.getARead() }

query predicate phiInputs(SsaPhiDefinition phi, SsaDefinition inp) { inp = phi.getAnInput() }

query predicate priorDefinitions(SsaUncertainWrite def, SsaDefinition prior) {
  prior = def.getPriorDefinition()
}

query predicate ultimate(SsaDefinition def, SsaDefinition u) {
  def instanceof SsaPhiDefinition and u = def.getAnUltimateDefinition()
}
