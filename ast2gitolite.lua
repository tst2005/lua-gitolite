local renderer = require "ast-renderer"

local tprint = require"tprint"

--local typeget = function(t) return t.tag or t.type end
local ast2gitolite = renderer("tag")

local gitolite = ast2gitolite:defs()

function gitolite:Comment(t)
	assert(#t<=1)
	return "#"..t[1]
end

function gitolite:ConfigLine(t)
	assert(#t<=1)
	return "config".." "..t[1]
end

function gitolite:DescLine(t)
	assert(#t<=2)
	return self:render(t[1]).." = "..self:render(t[2])
end

function gitolite:DescContent(t)
	assert(#t<=1)
	return '"'..t[1]..'"'
end

function gitolite:DescName(t)
	assert(#t<=1)
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
	assert(#t<=1)
	return t[1]
end

function gitolite:Group(t)
	assert(#t<=1)
	return t[1]
end

function gitolite:GroupDefLine(t)
	assert(#t<=2)
	return self:render(t[1]).." = "..self:render(t[2])
end

function gitolite:Members(t)
	return self:concat(t, " ")
end

function gitolite:Perm(t)
	assert(#t<=1)
	return t[1]
end

function gitolite:PermLine(t)
	return self:PermLineWithFilter(t)
end

function gitolite:PermLineWithFilter(t)
	if #t == 2 then
		return self:render(t[1]).." = "..self:render(t[2]) -- perm = members
	elseif #t == 3 then
		-- perm filter = group
		-- or
		-- perm = group comment
		if t[2].tag=="Filter" then
			return self:render(t[1]).." "..self:render(t[2]).." = "..self:render(t[3]) -- perm filter = members
		else
			return self:render(t[1]).." = "..self:render(t[2]).." "..self:render(t[3]) -- perm = members comment
		end
	elseif #t == 4 then
		return self:render(t[1]).." "..self:render(t[2]).." = "..self:render(t[3]).." "..self:render(t[4]) -- perms filter = members comment
	end
	error("too many content in PermLineWithFilter ?!")
end

function gitolite:Repo(t)
	assert(#t<=3)
	if #t==2 then
		return "repo".." "..self:render(t[1]).."\n"..self:render(t[2]).."\n"
	elseif #t == 3 then
		return "repo".." "..self:render(t[1]).." "..self:render(t[2]).."\n"..self:render(t[3]).."\n"
	end
end

function gitolite:RepoBody(t)
	return "\t"..self:concat(t, "\n\t")
end

function gitolite:RepoName(t)
	assert(#t<=1)
	return t[1]
end

function gitolite:UnmatchedData(t)
	assert(#t<=1)
	if t[1] and t[1]~="" then
		return "gitolite:UnmatchedData:"..t[1].."\n"
	end
	return ""
end

function gitolite:User(t)
	assert(#t<=1)
	return t[1]
end

return ast2gitolite
