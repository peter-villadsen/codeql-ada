import ada

from Subprogram s
where s.fromSource()
select s, s.getMetrics().getNumberOfStatements(), s.getMetrics().getCyclomaticComplexity()
