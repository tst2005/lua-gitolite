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
	gitolite <- {| ( repoline / commentline / descline / groupline / emptyline)* {:tag: '' -> "File" :} unmatched^-1 eof |} !.
	
	emptyline <- keepemptyline
	--emptyline <- skipemptyline

	--comment <- skipcomment
	comment <- keepcomment

	keepemptyline <- {| {:tag: '' -> "EmptyLine" :} |} %nl
	skipemptyline <- %nl

	keepcomment <- {| maybespaces {'#' [^%nl]* } {:tag: '' -> "Comment" :} |}
	skipcomment <- maybespaces '#' [^%nl]*

	commentline <- comment %nl
	maybespaces <- ws*
	spaces <- ws+
	ws <- %taborspace

	descline <- {| {:tag: '' -> "DescLine" :} descname maybespaces '=' maybespaces desccontent comment^-1 |} %nl
	descname <- {| {[a-zA-Z0-9_-]+} {:tag: '' -> "DescName" :} |}
	desccontent <- {| '"' {[^"]*} '"' {:tag: '' -> "DescContent" :} |}

	groupline <- {| {:tag: '' -> "GroupDefLine" :} groupname maybespaces '=' maybespaces members comment^-1 |} %nl
	groupname <- {| { "@" [a-zA-Z0-9_-]+ } {:tag: '' -> "Group" :} |}
	username  <- {| {[a-zA-Z0-9_-]+} {:tag: '' -> "User" :} |}
	--members <- {[a-zA-Z0-9, _-]+}
	members <- {| member (spaces member)* {:tag: '' -> "Members" :} |}
	member <- groupname / username

	repoline <- {| maybespaces 'repo' spaces reponame comment^-1 %nl repobody {:tag: '' -> "Repo" :} |}
	reponame <- {| { [a-zA-Z0-9_-]+ } {:tag: '' -> "RepoName" :} |}
	repobody <- {| (permline)+ {:tag: '' -> "RepoBody" :} |}
	--permline <- permline0 / permline1 / permline2 / permline3 / permline4 / permline5
	permline <- permline0 / permline1 / permline2 / permline5
	permline0 <- {| maybespaces "config" maybespaces {[^%nl]*} {:tag: '' -> "ConfigLine" :} |} %nl
	permline1 <- {| maybespaces perm maybespaces filter^-1 maybespaces '=' maybespaces members comment* {:tag: '' -> "PermLineWithFilter" :} |} %nl
	permline2 <- {| maybespaces perm maybespaces filter^-1 maybespaces '=' maybespaces members {:tag: '' -> "PermLineWithFilter" :} |} %nl
	--permline3 <- {| maybespaces perm maybespaces '=' maybespaces members comment* {:tag: '' -> "PermLine" :} |} %nl
	--permline4 <- {| maybespaces perm maybespaces '=' maybespaces members {:tag: '' -> "PermLine" :} |} %nl
	permline5 <- comment^-1 %nl
	--filter <- {| {[a-zA-Z/_-]+} |}
	filter <- {| {[^%s=]+} {:tag: '' -> "Filter" :} |}
	
	perm <- {| {"-" / "C" / ("RW" "+"^-1 ("CD" / "C" /"D")^-1 "M"^-1) / "R"} {:tag: '' -> "Perm" :} |}

	unmatched <- {| {:tag: '' -> "UnmatchedData" :} {.*} |}
	eof <- {| {:tag: '' -> "Eof" :} |}
]]

return function(data)
	return grammar:match( data )
end

--permmembers <- {| member ("," maybespaces member)* |}
--permmembers <- {| (member "," maybespaces)* member |}

--groupmembers <- {| member ("," maybespaces member)* |}
--groupmembers <- {| (member "," maybespaces)* member |}
--ws <- %s & !%nl  -- find a way to define "space + tab" only

