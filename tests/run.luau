local tests = {
	{ name = "load_config", run = require("./load_config") },
	{ name = "resolve_target", run = require("./resolve_target") },
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
