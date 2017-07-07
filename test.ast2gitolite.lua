
local ast2gitolite = require "ast2gitolite"

--if (...) == "-" then
	local tmpenv = {}
	local luacode = "return "..io.stdin:read("*a")
	local load = loadstring or load
	local ast = load(luacode, luacode, "t", tmpenv)()
	--print(t)
	--print("t = "..require"tprint"(t, {inline=false}))
	print(ast2gitolite(ast))
--	return
--end

