local cleanError = require("../lib/clean_error")

return function()
	assert(
		cleanError("/path/to/lib/save_asset:33: Instance not found") == "Instance not found",
		"an absolute script path prefix should be stripped"
	)
	assert(
		cleanError("main:12: Unknown option: --bogus") == "Unknown option: --bogus",
		"a bare script name prefix should be stripped"
	)

	-- Messages without a location prefix are left alone
	assert(cleanError("Plain message") == "Plain message", "a message with no prefix should be unchanged")
	assert(cleanError("Ratio 3:4 is fine") == "Ratio 3:4 is fine", "a colon mid-message is not a location prefix")

	-- Only the leading location is stripped, not later ones in the body
	assert(cleanError("a:1: b:2: rest") == "b:2: rest", "only the leading location should be stripped")
end
