BEGIN "desc"

desc["gitolite-admin"]                          = "gitolite-admin"
desc["foo"]					= "my repo named foo"
desc["bar"]					= "bar"

END "desc"

BEGIN "group"

group["@g1"] = "user1 user2 user3"
group["@g2"] = "user5 user3 admin1"
group["@gg"] = "@g1 @g2 admin2"

END "group"

BEGIN "repo"

repo    "gitolite-admin" (function(PERM)
	PERM["RW+"]                     = "admin1 admin2"
end)

repo	"foo"		(function(PERM)
	PERM["RW+CD"]			= "@g2"
	PERM["R"]			= "@g1"
end)

repo	"bar"		(function(PERM)
	PERM["RW+CD"]                           = "user9"
	PERM[{"R", "master$"}]                  = "@gg"
	PERM[{"-", "master$"}]                  = "@gg"
	PERM["RW+CD"]                           = "@gg"
end)

END "repo"

