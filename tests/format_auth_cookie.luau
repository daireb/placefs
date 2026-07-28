local formatAuthCookie = require("../lib/format_auth_cookie")

return function()
	assert(formatAuthCookie("ABC123") == ".ROBLOSECURITY=ABC123", "a bare token should gain the prefix")
	assert(
		formatAuthCookie(".ROBLOSECURITY=ABC123") == ".ROBLOSECURITY=ABC123",
		"an already-prefixed value should be unchanged"
	)
	assert(formatAuthCookie("  ABC123\n") == ".ROBLOSECURITY=ABC123", "surrounding whitespace should be stripped")
	assert(
		formatAuthCookie("\n.ROBLOSECURITY=ABC123  ") == ".ROBLOSECURITY=ABC123",
		"whitespace around a prefixed value should be stripped"
	)

	local ok = pcall(formatAuthCookie, "   ")
	assert(not ok, "Expected an empty cookie value to error")
end
