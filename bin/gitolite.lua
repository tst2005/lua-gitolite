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
--local content = io.open("conf/gitolite.lua", "r"):read("*a")
local content = io.stdin:read("*a")
local f = load(content, "@conf/gitolite.lua", "t", e)
assert(f)()

