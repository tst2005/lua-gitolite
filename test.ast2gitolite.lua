
local x = require "ast2gitolite"

--if (...) == "-" then
	local tmpenv = {}
	local luacode = "return "..io.stdin:read("*a")
	local load = load or loadstring
	local t = load(luacode, luacode, "t", tmpenv)()
	--print(t)
	print("t = "..require"tprint"(t, {inline=false}))
	print(x:render(t))
--	return
--end

