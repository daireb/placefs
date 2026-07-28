local process = require("@lune/process")
local roblox = require("@lune/roblox")

local formatAuthCookie = require("./format_auth_cookie")

return function(): string
	-- Pull from studio install
	local ok, auth_cookie = pcall(roblox.getAuthCookie)

	if ok and auth_cookie ~= nil then
		return auth_cookie
	end

	-- Fall back to the environment when Studio is unavailable
	local fromEnvironment = process.env.ROBLOSECURITY

	if fromEnvironment ~= nil and fromEnvironment ~= "" then
		return formatAuthCookie(fromEnvironment)
	end

	error(
		"Failed to retrieve ROBLOSECURITY cookie. Log in through Roblox Studio, "
			.. "or set the ROBLOSECURITY environment variable."
	)
end
