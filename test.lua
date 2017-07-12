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

local conv = require "ast-conv"
conv.atype = atype

local indexgroups = conv.indexgroups
local expandgroup2users = conv.expandgroup2users
local applygroups = conv.applygroups

local groups = indexgroups(ast)
groups = expandgroup2users(groups)
applygroups(ast, groups)

--print(tprint(ast, cfg))

assert(type(ast2gitolite)=="table")
local gitolite = ast2gitolite(ast)
assert(type(gitolite)=="string")
io.stdout:write( gitolite )

--print(require"mini.tprint.better"(x, {inline=false}))
