/**
 * @name TODO/FIXME comment
 * @description Comments tagged TODO, FIXME, XXX, or HACK mark known-incomplete
 *              or known-wrong code; tracking them surfaces technical debt that
 *              might otherwise be forgotten.
 * @id ada/todo-comment
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

from Raw::Comment c
where c.getText().regexpMatch("(?i).*\\b(TODO|FIXME|XXX|HACK)\\b.*")
select c, "Comment marks incomplete or known-wrong code: " + c.getText()
