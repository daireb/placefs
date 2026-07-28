local formatAuthCookie = require("../lib/format_auth_cookie")

return function()
	assert(formatAuthCookie("ABC123") == ".ROBLOSECURITY=ABC123")
	assert(formatAuthCookie(".ROBLOSECURITY=ABC123") == ".ROBLOSECURITY=ABC123")
	assert(formatAuthCookie("  ABC123\n") == ".ROBLOSECURITY=ABC123")
	assert(formatAuthCookie("\n.ROBLOSECURITY=ABC123  ") == ".ROBLOSECURITY=ABC123")

	local ok = pcall(formatAuthCookie, "   ")
	assert(not ok, "Expected an empty cookie value to error")
end
