
local ast2gitolite = require "ast2gitolite"

--if (...) == "-" then
	local tmpenv = {}
	local luacode = io.stdin:read("*a")
	local load = loadstring or load
	local ast = load(luacode, luacode, "t", tmpenv)()
	assert(ast)
	--print(t)
	--print("t = "..require"tprint"(ast, {inline=false}))
	print(ast2gitolite(ast))
--	return
--end

