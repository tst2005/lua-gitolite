local renderer = require "ast-renderer"

local tprint = require"tprint"

--local typeget = function(t) return t.tag or t.type end
local ast2gitolite = renderer("tag")

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
	return t[1]
end

function gitolite:GroupDefLine(t)
	return self:render(t[1]).." = "..self:render(t[2])
end

function gitolite:Members(t)
	return self:concat(t, " ")
end

function gitolite:Perm(t)
	return t[1]
end

function gitolite:PermLine(t)
	return self:PermLineWithFilter(t)
end

function gitolite:PermLineWithFilter(t)
	if #t == 2 then
		return self:render(t[1]).." = "..self:render(t[2])
	elseif #t == 3 then
		-- perm filter = group
		-- or
		-- perm = group comment
		if t[2].tag=="Filter" then
			return self:render(t[1]).." "..self:render(t[2]).." = "..self:render(t[3])
		else
			return self:render(t[1]).." = "..self:render(t[2]).." "..self:render(t[3])
		end
	elseif #t == 4 then
		return self:render(t[1]).." "..self:render(t[2]).." = "..self:render(t[3]).." "..self:render(t[4])
	end
	error("too many content in PermLineWithFilter ?!")
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
