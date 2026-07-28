local fs = require("@lune/fs")
local process = require("@lune/process")

local SINGLE_CONFIG = "/tmp/placefs-cli-single.toml"
local MULTI_CONFIG = "/tmp/placefs-cli-multi.toml"
local LEGACY_CONFIG = "/tmp/placefs-cli-legacy.toml"
local STRAY_CONFIG = "/tmp/placefs-cli-stray.toml"
local PROJECT_OUTPUT = "/tmp/placefs-cli-out.project.json"

local SINGLE = [==[
[places.main]
placeId = 1234567890

[places.main.assets]
"game.Workspace.Map" = "./assets/map.rbxm"
]==]

local MULTI = [==[
[places.lobby]
placeId = 222

[places.lobby.assets]
"game.Workspace.Lobby" = "./assets/lobby.rbxm"

[places.maps]
placeId = 111

[places.maps.assets]
"game.Workspace.Maps" = { path = "./assets/maps", maxExpansionDepth = 1 }
]==]

local LEGACY = [==[
[settings]
placeId = 123

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
]==]

type Result = {
	code: number,
	output: string,
}

local function placefs(args: { string }): Result
	local result = process.exec("lune", { "run", "main.luau", table.unpack(args) })
	return {
		code = result.code,
		output = result.stdout .. result.stderr,
	}
end

local function expectSuccess(args: { string }, contains: string): Result
	local result = placefs(args)
	assert(result.code == 0, `Expected success from '{table.concat(args, " ")}', got code {result.code}`)
	assert(result.output:find(contains, 1, true), `Expected output containing '{contains}', got:\n{result.output}`)
	return result
end

local function expectCleanFailure(args: { string }, contains: string)
	local result = placefs(args)
	assert(result.code ~= 0, `Expected failure from '{table.concat(args, " ")}', got code 0`)
	assert(result.output:find("[placefs] Error:", 1, true), `Expected a '[placefs] Error:' line, got:\n{result.output}`)
	assert(not result.output:find("[Stack Begin]", 1, true), `Expected no stack trace, got:\n{result.output}`)
	assert(result.output:find(contains, 1, true), `Expected output containing '{contains}', got:\n{result.output}`)
end

return function()
	-- Inherited environment defaults would make these cases non-deterministic
	process.env.PLACEFS_CONFIG = nil
	process.env.PLACEFS_PLACE = nil

	fs.writeFile(SINGLE_CONFIG, SINGLE)
	fs.writeFile(MULTI_CONFIG, MULTI)
	fs.writeFile(LEGACY_CONFIG, LEGACY)

	local ok, err = pcall(function()
		expectSuccess({ "--version" }, "placefs")
		expectSuccess({ "--help" }, "SUBCOMMANDS")

		-- Regression: a subcommand placed after a shared option must still run
		expectSuccess({ "-c", MULTI_CONFIG, "places" }, "lobby")
		expectSuccess({ "--config", MULTI_CONFIG, "places" }, "maps")
		expectSuccess({ "--config=" .. MULTI_CONFIG, "places" }, "maps")
		expectSuccess({ "places", "-c", MULTI_CONFIG }, "lobby")

		-- Errors are single lines with a non-zero exit and no stack trace
		expectCleanFailure({ "--bogus" }, "Unknown option: --bogus")
		expectCleanFailure({ "-c", "/tmp/placefs-cli-missing.toml", "--all" }, "does not exist")
		expectCleanFailure({ "-c", MULTI_CONFIG, "--place", "nope", "--all" }, "Unknown place 'nope'")
		expectCleanFailure({ "-c", LEGACY_CONFIG, "--all" }, "placefs v0 config")

		-- A misnamed mapping section is a loud error, not a silently dropped mapping
		fs.writeFile(
			STRAY_CONFIG,
			table.concat({
				"[places.maps]",
				"placeId = 111",
				"",
				"[places.maps.assets]",
				'"game.Workspace.A" = "./assets/a.rbxm"',
				"",
				"[places.maps.instances]",
				'"game.Workspace.B" = "./assets/b.rbxm"',
			}, "\n")
		)
		expectCleanFailure({ "-c", STRAY_CONFIG, "places" }, "unknown key(s) in places.maps: instances")

		-- Multi-place configs still require an explicit place for positionals
		expectCleanFailure({ "-c", MULTI_CONFIG, "game.Workspace.Maps" }, "--place is required")

		-- A single-place config resolves the place without --place. The sync
		-- itself needs network, so assert only that resolution got past selection.
		local result = placefs({ "-c", SINGLE_CONFIG, "--dry-run", "game.Workspace.Map" })
		assert(
			not result.output:find("--place is required", 1, true),
			`Single-place config should not demand --place, got:\n{result.output}`
		)

		-- project derives its filename from the place, and -o needs a place when ambiguous
		expectSuccess({ "-c", SINGLE_CONFIG, "project", "-o", PROJECT_OUTPUT }, "Generated")
		assert(fs.isFile(PROJECT_OUTPUT), "project should write the requested output file")
		expectCleanFailure({ "-c", MULTI_CONFIG, "project", "-o", PROJECT_OUTPUT }, "--output requires --place")
	end)

	for _, path in { SINGLE_CONFIG, MULTI_CONFIG, LEGACY_CONFIG, STRAY_CONFIG, PROJECT_OUTPUT } do
		if fs.isFile(path) then
			fs.removeFile(path)
		end
	end

	assert(ok, err)
end
