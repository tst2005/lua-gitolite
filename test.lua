local tprint = require "tprint"

local cfg;cfg = {inline=false, seen=setmetatable({}, {__newindex=function() end, __index=function() return nil end})}
-- recursivefound = function(t, lvl, cfg) cfg.seen[t]=nil return tprint(t,cfg) end}


if false then
	do
	local lpeg = require "lulpeg"
	local re = lpeg.re
	package.loaded.lpeg = lpeg
	package.loaded.re = re
	end
end

local gitolite2ast = require "gitolite-parser"
local ast2gitolite = require "ast2gitolite"
local atype = function(...) return ast2gitolite:type(...) end

local data = io.stdin:read("*a")
local ast = gitolite2ast( data )

local groups = {}
local function indexgroups(ast)
	for i, line in pairs(ast) do
		if atype(line)=="GroupDefLine" then
			assert(atype(line[1])=="Group")
			assert(atype(line[2])=="Members")
			--print("index group:", line[1][1])
			groups[line[1][1]] = line[2]
		end
	end
end
local function expandgroup2users(src)
	local r = {}
	for groupname, members in pairs(src) do
		assert(atype(members)=="Members")
		for i, u_or_g in ipairs(members) do
			assert(atype(u_or_g)=="User" or atype(u_or_g)=="Group")
			if atype(u_or_g)=="Group" then
				--print(groupname, "something to do")
				--print(groupname, "replace i="..i, "groupname=", u_or_g[1])
				members[i]=src[u_or_g[1]]
			end
		end
	end
	for groupname, members in pairs(src) do
		assert(atype(members)=="Members")
		--for i, u_or_g in ipairs(members) do
		local i=0
		while true do
			i=i+1
			local u_or_g = members[i]
			if u_or_g ==nil then break end
			assert(atype(u_or_g)=="User" or atype(u_or_g)=="Members")
			if atype(u_or_g)=="Members" then
				table.remove(members, i)
				for _i, ug in ipairs(u_or_g) do
					table.insert(members, i, ug)
				end
			end
		end
		r[groupname] = members
	end
	return r
end
local function applygroups(t)
	if type(t)=="table" then
		if atype(t)=="GroupDefLine" then return t end
		for i, v in ipairs(t) do
			--print(i,v)
			if atype(v) == "Group" then
				local groupname = v[1]
				assert(groups[groupname])
--				print("replace", groupname)
				t[i]=groups[groupname]
			end
		end
		for k, v in pairs(t) do
			--if type(k)~="number" then
				applygroups(v)
			--end
		end
	end
	return t
end

indexgroups(ast)
groups = expandgroup2users(groups)
applygroups(ast)

--print(tprint(ast, cfg))


local gitolite = ast2gitolite(ast)
io.stdout:write( gitolite )

--print(require"mini.tprint.better"(x, {inline=false}))
