local autocopy = require "mini.copy"
local tcopy = require "mini.table.shallowcopy"
-- local way = { ["table"] = function(src) return tcopy(src) end, }

local M = {}

local function changetag(src, tag_from, tag_to)
	local r = {}
	for k,v in pairs(autocopy(src)) do
		local new_k = (k==tag_from) and tag_to or k
		local new_v = autocopy(v)
		if type(v)=="table" then
			new_v=changetag(new_v,tag_from, tag_to)
		end
		r[new_k]=new_v
	end
	return r
end



local function indexgroups(ast)
	local atype = M.atype
	local groups = {}
	for i, line in pairs(ast) do
		if atype(line)=="GroupDefLine" then
			assert(atype(line[1])=="Group")
			assert(atype(line[2])=="Members")
			--print("index group:", line[1][1])
			groups[line[1][1]] = line[2]
		end
	end
	return groups
end
local function expandgroup2users(src)
	local atype = M.atype
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
local function applygroups(t, groups)
	local atype = M.atype
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
				applygroups(v, groups)
			--end
		end
	end
	return t
end
M.changetag = changetag
M.indexgroups = indexgroups
M.expandgroup2users = expandgroup2users
M.applygroups = applygroups

return M
