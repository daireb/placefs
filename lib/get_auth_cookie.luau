local roblox = require("@lune/roblox")

return function(): string
	-- Pull from studio install
	local auth_cookie = roblox.getAuthCookie()

	-- TODO: Fallback to environment variable if studio install fails

	-- Final check and return
	if auth_cookie ~= nil then
		return auth_cookie
	else
		error("Failed to retrieve ROBLOSECURITY cookie.")
	end
end
