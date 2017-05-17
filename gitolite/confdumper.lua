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
