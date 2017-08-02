if false then
	do
	local lpeg = require "lulpeg"
	local re = lpeg.re
	package.loaded.lpeg = lpeg
	package.loaded.re = re
	end
end

local gitolite = require "gitolite-parser"

local data = [[
### Repo Descriptions 
@group1 = u1 u2

## foo
gitolite-admin = "gitolite-admin"

foo = "FOO"	# comm
@g1 = ab cd de
@g2 = xy @g1
# foo

repo    foo-bar                  # alias=stuff
 RW = user


repo  foo-repo  # comment
 RW = a b c        # comm
 RW = x y
 RW = y
 RW      = d e

# COMM
repo alpha
 RW = abc cde
 RW+ = feg ijh
 R = a
 RW = b
 RW+ = c
 RW+C = d
 RW+D = e
 RW+CD temp/ = f

## x
#x
#

@dxx-mttt = ac efqew greghe yrhry 54t24 69hk40p

]]

if ... == "-" then
	data = io.stdin:read("*a")
end

local x = gitolite( data )
print("return "..require"mini.tprint.better"(x, {inline=false}))

