local tests = {
	{ name = "clean_error", run = require("./clean_error") },
	{ name = "cli", run = require("./cli") },
	{ name = "find_unpacked_variants", run = require("./find_unpacked_variants") },
	{ name = "format_auth_cookie", run = require("./format_auth_cookie") },
	{ name = "load_config", run = require("./load_config") },
	{ name = "parse_args", run = require("./parse_args") },
	{ name = "resolve_target", run = require("./resolve_target") },
	{ name = "save_asset", run = require("./save_asset") },
}

local failures = 0

for _, test in tests do
	local ok, message = pcall(test.run)
	if ok then
		print(`[test] PASS {test.name}`)
	else
		failures += 1
		print(`[test] FAIL {test.name}: {tostring(message)}`)
	end
end

if failures > 0 then
	error(`{failures} test(s) failed`)
end

print(`[test] {#tests} test(s) passed`)
