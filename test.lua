local tprint = require "tprint"

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
	for _i, line in pairs(ast) do
		if atype(line)=="GroupDefLine" then
			--print(tprint(line, {inline=false}))
			assert(atype(line[1])=="Group")
			assert(atype(line[2])=="Members")
			--print(line[1][1], tprint(line[2], {inline=true}))
			print("index group:", line[1][1])
			groups[line[1][1]] = line[2]
		end
	end
end
local function expandgroup2users(src)
	local r = {}
	for groupname, members in pairs(src) do
		assert(atype(members)=="Members")
		for _i, u_or_g in ipairs(members) do
			assert(atype(u_or_g)=="User" or atype(u_or_g)=="Group")
			if atype(u_or_g)=="Group" then
				print("something to do")
				--table.remove()
			end
		end
	end
	return r
end

indexgroups(ast)
expandgroup2users(groups)

--groups = expandgroup2users(groups)

--[[
local gitolite = ast2gitolite(ast)
io.stdout:write( gitolite )
]]--

--print(require"mini.tprint.better"(x, {inline=false}))
