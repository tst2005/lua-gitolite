#!/usr/bin/env lua

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

if #{...} == 0 then
	print("Usage: gitolite-confdumper <path/to/gitolite.conf.lua|'-'>")
	os.exit(1)
end
local content
if (...) == "-" then
	content = io.stdin:read("*a")
else
	content = io.open( (...), "r"):read("*a")
end
local f = load(content, "@conf/gitolite.lua", "t", e)
assert(f)()

