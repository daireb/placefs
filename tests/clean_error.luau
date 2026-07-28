local cleanError = require("../lib/clean_error")

return function()
	assert(cleanError("/path/to/lib/save_asset:33: Instance not found") == "Instance not found")
	assert(cleanError("main:12: Unknown option: --bogus") == "Unknown option: --bogus")

	-- Messages without a location prefix are left alone
	assert(cleanError("Plain message") == "Plain message")
	assert(cleanError("Ratio 3:4 is fine") == "Ratio 3:4 is fine")

	-- Only the leading location is stripped, not later ones in the body
	assert(cleanError("a:1: b:2: rest") == "b:2: rest")
end
