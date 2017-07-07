local renderer = require "ast-renderer"

--local typeget = function(t) return t.tag or t.type end
local ast2gitolite = renderer("tag")

--[===[ -- SHELL QUOTING --
local function prot(s)
	return s:gsub("[\"\\$`]", function(cap) return "\\"..cap end)
end
local function quotestring(s)
	return '"'..s:gsub("[\"\\]", function(cap) return "\\"..cap end)..'"'
end
local function squotestring(s)
	return "'"..s:gsub("['\\]", function(cap)
		if cap == "'" then
			return [['"'"']] --  ' -> '"'"'
		else
			return "\\"..cap
		end
	end).."'"
end
]===]--


local gitolite = ast2gitolite:defs()

function gitolite:Comment(t)
	return "#"..t[1]
end

function gitolite:ConfigLine(t)
	return "config".." "..t[1]
end

function gitolite:DescLine(t)
	return self:render(t[1]).." = "..self:render(t[2])
end

function gitolite:DescContent(t)
	return '"'..t[1]..'"'
end

function gitolite:DescName(t)
	return t[1]
end

function gitolite:EmptyLine(t)
	return ""
end

function gitolite:Eof(t)
	return ""
end

function gitolite:File(t)
	return self:concat(t, "\n")
end

function gitolite:Filter(t)
	return t[1]
end

function gitolite:Group(t)
	return "Group"
end	

function gitolite:GroupDefLine(t)
	return "gitolite:GroupDefLine"
end

function gitolite:Members(t)
	return self:concat(t, " ")
end

function gitolite:Perm(t)
	return t[1]
end

function gitolite:PermLine(t)
	return "PermLine"
end

function gitolite:PermLineWithFilter(t)
	return "PermLineWithFilter"
end

function gitolite:Repo(t)
	return "repo".." "..self:render(t[1]).."\n"..self:render(t[2]).."\n"
end

function gitolite:RepoBody(t)
	return "\t"..self:concat(t, "\n\t")
end

function gitolite:RepoName(t)
	return t[1]
end

function gitolite:UnmatchedData(t)
	if t[1] and t[1]~="" then
		return "gitolite:UnmatchedData:"..t[1].."\n"
	end
	return ""
end

function gitolite:User(t)
	return t[1]
end

return ast2gitolite
