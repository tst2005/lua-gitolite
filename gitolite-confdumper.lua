#!/usr/bin/env lua
do --{{
local sources, priorities = {}, {};assert(not sources["mini.load"],"module already exists")sources["mini.load"]=([===[-- <pack mini.load> --
----------------

-- <thirdparty>
-- pl.compat : https://github.com/stevedonovan/Penlight/blob/master/lua/pl/compat.lua
-- Copyright (c) 2009 Steve Donovan, David Manura
-- License : https://github.com/stevedonovan/Penlight/blob/master/LICENSE.md

--- Lua 5.1/5.2 compatibility
-- The exported function `load` is Lua 5.2 compatible.
-- `compat.setfenv` and `compat.getfenv` are available for Lua 5.2, although
-- they are not always guaranteed to work.
-- @module pl.compat

----------------
-- Load Lua code as a text or binary chunk.
-- @param ld code string or loader
-- @param[opt] source name of chunk for errors
-- @param[opt] mode 'b', 't' or 'bt'
-- @param[opt] env environment to load the chunk in
-- @function compat.load

---------------
-- Get environment of a function.
-- With Lua 5.2, may return nil for a function with no global references!
-- Based on code by [Sergey Rozhenko](http://lua-users.org/lists/lua-l/2010-06/msg00313.html)
-- @param f a function or a call stack reference
-- @function compat.setfenv

---------------
-- Set environment of a function
-- @param f a function or a call stack reference
-- @param env a table that becomes the new environment of `f`
-- @function compat.setfenv

local compat_load
if pcall(load, '') then -- check if it's lua 5.2+ or LuaJIT's with a compatible load
	compat_load = load
else
	local native_load = load
	function compat_load(str,src,mode,env)
		local chunk,err
		if type(str) == 'string' then
			if str:byte(1) == 27 and not (mode or 'bt'):find 'b' then
				return nil,"attempt to load a binary chunk"
			end
			chunk,err = loadstring(str,src)
		else
			chunk,err = native_load(str,src)
		end
		if chunk and env then setfenv(chunk,env) end
		return chunk,err
	end
end
-- </thirdparty>

return compat_load
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["mini.table.writeorder"],"module already exists")sources["mini.table.writeorder"]=([===[-- <pack mini.table.writeorder> --

-- http://lua-users.org/wiki/OrderedTable

-- create an empty table that is able to remind the write order.
-- Warning: the order is the first creation. Remove or change will change anything.

local function low_newtable(t, mt)
	local nextkey, firstkey = {}, {}
	nextkey[nextkey] = firstkey
 
	local function onext(self, key)
		while key ~= nil do
			key = nextkey[key]
			local val = self[key]
			if val ~= nil then return key, val end
		end
	end
 
--	local mt = {}
 
	function mt:__newindex(key, val)
--print("DEBUG: writeorder.newtable: rawset", key, val)
		rawset(self, key, val)
		if nextkey[key] == nil then
			nextkey[nextkey[nextkey]] = key		-- lastkey = nextkey[nextkey] ; nextkey[lastkey] = key
								-- At the first write, lastkey is firstkey, then nextkey[firstkey] = key
			nextkey[nextkey] = key			-- lastkey = key
		end
	end
 
	function mt:__pairs() return onext, self, firstkey end
 
	return setmetatable(t, mt)
end
local function newtable()
	return low_newtable({}, {})
end
local function updatetable(t)
	local mt = getmetatable(t) or {}
	assert(mt.__newindex==nil, "meta __newindex already set")
	assert( mt.__pairs==nil, "meta __pairs already set")
	return low_newtable(t, mt)
end


local function pairs52(t, ...)
	return ( (getmetatable(t) or {}).__pairs or pairs)(t, ...)
end
return setmetatable({
	newtable=newtable,
	updatetable = updatetable,
	pairs=pairs52
}, {
	__call=function(_, t)
		if not t then
			return newtable()
		end
		return updatetable(t)
	end,
})
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["mini.string.split"],"module already exists")sources["mini.string.split"]=([===[-- <pack mini.string.split> --

local G = {string={find=string.find, sub=string.sub}, type=type, table={insert=table.insert}}

-- the strong's split function https://github.com/tst2005/strong/blob/master/strong.lua#L189-L205
return function(self, pat, plain, max)
	--self=type(self)=="table" and self[1] or self
	assert(type(self)=="string")
	assert(type(pat)=="string")
	--plain
	assert(not max or type(max)=="number")
	local tinsert = table.insert or function(t,v) t[#t+1]=v end
	local find, sub = string.find, string.sub
	local t = {}
	while true do
		local pos1, pos2 = find(self, pat, 1, plain or false)
		if not pos1 or pos1 > pos2 or max and #t>=max then
			tinsert(t, self)
			return t
		end
		tinsert(t, sub(self, 1, pos1 - 1))
		self = sub(self, pos2 + 1)
	end
end
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["mini.table.uniq.inplace"],"module already exists")sources["mini.table.uniq.inplace"]=([===[-- <pack mini.table.uniq.inplace> --
return function(t)
	local table_remove = table.remove
	local last = nil
	for i=#t,1,-1 do
		local v = t[i]
		if last ~= nil and last==v then
			table_remove(t,i)
		else
			last=v
		end
	end
	return t
end
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["gitolite.confdumper"],"module already exists")sources["gitolite.confdumper"]=([===[-- <pack gitolite.confdumper> --
local newtable = assert(require "mini.table.writeorder".newtable)
local wopairs = assert(require "mini.table.writeorder".pairs)
local split = require"mini.string.split"

local hooks = {}
local function BEGIN(name)
	if hooks[name] then
		hooks[name]("BEGIN", name)
	else
		print("BEGIN", name)
	end
end
local function END(name)
	if hooks[name] then
		hooks[name]("END", name)
	else
		print("END", name)
	end
end

local function expand_group_to_users(members, groups)
	local expanded = {}
	for i, m in ipairs(members) do
		assert(type(m)=="string")
		if m:find("@") then -- is a group to expand
			local g = groups[m]
			for i2, v2 in ipairs(expand_group_to_users(g, groups)) do
				table.insert(expanded, v2)
			end
		else
			table.insert(expanded, m)
		end
	end
	return expanded
end


local desc=newtable()
hooks.desc = function(action, name)
	if action~="END" then return end
	print("")
	print("# Descriptions")
	for k,v in wopairs(desc) do
		print(k.." = "..'"'..v..'"')
	end
end

local group=newtable()
hooks.group = function(action, name)
	if action~="END" then return end
	print("")
	print("# Groups")
	local groups = newtable()
	for g,members in wopairs(group) do
		if type(members) == "string" then
			members = split(members, "%s+")
		end
		groups[g] = members
	end
	group = groups
	for g,members in wopairs(group) do
		print(g.." = "..table.concat(members," "))
	end
end

local allrepo = {}
hooks.repo = function(action, name)
	if action~="END" then return end
	for _i,repo in ipairs(allrepo) do
		print("")
		--io.stderr:write("# repo "..repo.name.."\t # "..#repo.." perm"..(#repo>1 and "s" or "").."\n")
		print("repo "..repo.name)
		for _, line in ipairs(repo) do
			if line.perm then
				local members = expand_group_to_users(line[2], group)
				table.sort(members)
				require"mini.table.uniq.inplace"(members)
				print("", line[1][1], line[1][2] or "", "\t= "..table.concat(members, " "))
			else
				print("", line[1][1], line[1][2] or "", "\t= "..'"'..line[2]..'"')
			end
		end
	end
end


local comments={}
local comment = function(line)
	--table.insert(comments, line)
end

local MEMBERS = function(s)
	return split(s, "%s+")
end

--local validperms = require "mini.lookupify" {"-", "R","RW", "RWC", "RWCD", "RW+", "RW+C", "RW+CD", "C", }
--print(require"mini.tprint.better"(validperms))

local y=true
local validperms = {["-"]=y, ["R"]=y,["RW"]=y, ["RWC"]=y, ["RWCD"]=y, ["RW+"]=y, ["RW+C"]=y, ["RW+CD"]=y, ["C"]=y}

local currentrepo=nil
local function repo(name)
	if currentrepo then
		error("repository definition missing for "..currentrepo)
	end
	currentrepo=name
	--print("repo "..name)
	return function(permfunc)
		local repodef = {}
		local PERMproxy = setmetatable({}, {
			__newindex = function(_, k, v)
				if type(k)=="string" then -- format PERM["R"]=v
					k={k}
				end
				assert(type(k)=="table" and #k>=1 and #k<=2)
				local def = {perm=false, k, v}
				if validperms[k[1]] then
					def.perm=true
					if type(v) == "string" then
						v = MEMBERS(v)
					end
					assert(type(v)=="table")
					def[2]=v
				end
				repodef[#repodef+1] = def
			end
		})
		permfunc(PERMproxy)
		repodef.name=name
		table.insert(allrepo, repodef)
		currentrepo=nil
	end
end



local M = {
	BEGIN = BEGIN,
	END = END,
	repo = repo,
	desc = desc,
	group = group,
	comment = comment,
	MEMBERS = MEMBERS,
}

return M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
local add = function(name, rawcode)
	if not preload[name] then
	        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
	else
		print("WARNING: overwrite "..name)
	end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end; --}};

local confgdumper = require "gitolite.confdumper"

local e = {
	BEGIN = confgdumper.BEGIN,
	END = confgdumper.END,
	repo = confgdumper.repo,
	desc = confgdumper.desc,
	group = confgdumper.group,
	comment = confgdumper.comment,
	MEMBERS = confgdumper.MEMBERS,
}
e._G = e

--local env = require "mini.proxy.ro2rw"
local load = require "mini.load"
--local content = io.open("conf/gitolite.lua", "r"):read("*a")
local content = io.stdin:read("*a")
local f = load(content, "@conf/gitolite.lua", "t", e)
assert(f)()

