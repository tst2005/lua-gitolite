local re = require "re"

local re_internal_def
do
	local lpeg = require"lpeg"
	local locale = lpeg.locale -- backup the function
	lpeg.locale = function(t, ...)
		re_internal_def = t
		return locale(t, ...)
	end
	re.updatelocale() -- will internaly call lpeg.locale(...)

	lpeg.locale = locale -- restore the function

	-- patch the internal data
	if re_internal_def.nl then
		re_internal_def.tab = lpeg.P"\t"	-- tab
		re_internal_def.taborspace = lpeg.S" \t" -- space or tab
--		re_internal_def.lf = lpeg.P"\n"		-- lF
--		re_internal_def.cr = lpeg.P"\r"		-- CR
--		re_internal_def.crlf = lpeg.P"\r\n"	-- CRLF
	end
end

local grammar = re.compile[[
	gitolite <- {| ( repoline / commentline / descline / groupline / emptyline)* {:tag: '' -> 'lines' :} unmatched^-1 eof |} !.
	
	emptyline <- {| {:tag: '' -> "emptyline" :} |} %nl

	commentline <- comment %nl
	comment <- skipcomment
	--comment <- keepcomment
	keepcomment <- {| maybespaces {'#' [^%nl]* } {:tag: '' -> "comment" :} |}
	skipcomment <- maybespaces '#' [^%nl]*
	maybespaces <- ws*
	spaces <- ws+
	ws <- %taborspace

	descline <- {| {:tag: '' -> "desc" :} descname maybespaces '=' maybespaces desccontent comment^-1 |} %nl
	descname <- {| {[a-zA-Z0-9_-]+} {:tag: '' -> "desc-name" :} |}
	desccontent <- {| '"' {[^"]*} '"' {:tag: '' -> "desc-content" :} |}

	groupline <- {| {:tag: '' -> "group" :} groupname maybespaces '=' maybespaces groupmembers comment^-1 |} %nl
	groupname <- {| { "@" [a-zA-Z0-9_-]+ } {:tag: '' -> "group-name" :} |}
	username  <- {[a-zA-Z0-9_-]+}
	--groupmembers <- {[a-zA-Z0-9, _-]+}
	groupmembers <- {| member (spaces member)* {:tag: '' -> "group-members" :} |}
	member <- groupname / username

	repoline <- {| maybespaces 'repo' spaces reponame comment^-1 %nl repobody {:tag: '' -> "repo" :} |}
	reponame <- { [a-zA-Z0-9_-]+ }
	repobody <- (permline)+
	permline <- permline0 / permline1 / permline2 / permline3 / permline4 / permline5
	permline0 <- {| maybespaces "config" {[^%nl]*} {:tag: '' -> "config" :} |} %nl
	permline1 <- {| maybespaces perm maybespaces filter maybespaces '=' maybespaces permmembers comment* |} %nl
	permline2 <- {| maybespaces perm maybespaces filter maybespaces '=' maybespaces permmembers |} %nl
	permline3 <- {| maybespaces perm maybespaces '=' maybespaces permmembers comment* |} %nl
	permline4 <- {| maybespaces perm maybespaces '=' maybespaces permmembers |} %nl
	permline5 <- comment^-1 %nl
	--filter <- {| {[a-zA-Z/_-]+} |}
	filter <- {| {%S+} {:tag: '' -> "filter" :} |}
	
	perm <- {| {"-" / "C" / ("RW" "+"^-1 ("CD" / "C" /"D")^-1 "M"^-1) / "R"} {:tag: '' -> "perm" :} |}
	permmembers <- {| member (spaces member)* |}

	unmatched <- {| {:tag: '' -> "unmatched-data" :} {.*} |}
	eof <- {| {:tag: '' -> "eof" :} |}
]]

return function(data)
	return grammar:match( data )
end

--permmembers <- {| member ("," maybespaces member)* |}
--permmembers <- {| (member "," maybespaces)* member |}

--groupmembers <- {| member ("," maybespaces member)* |}
--groupmembers <- {| (member "," maybespaces)* member |}
--ws <- %s & !%nl  -- find a way to define "space + tab" only

