local fs = require("@lune/fs")

local loadConfig = require("../lib/load_config")

local PATH = "/tmp/placefs-load-config-test.toml"

local function write(text: string)
	fs.writeFile(PATH, text)
end

local function load(text: string)
	write(text)
	return loadConfig(PATH)
end

local function expectError(text: string, expected: string)
	write(text)
	local ok, message = pcall(loadConfig, PATH)
	assert(not ok, `Expected config to be rejected:\n{text}`)
	assert(
		tostring(message):find(expected, 1, true),
		`Expected error containing '{expected}', got '{tostring(message)}'`
	)
end

local function entryFor(config, placeName: string, robloxPath: string)
	for _, entry in config.places[placeName].map do
		if entry.robloxPath == robloxPath then
			return entry
		end
	end
	return nil
end

return function()
	local ok, err = pcall(function()
		-- String shorthand and table form, plus depth precedence
		local config = load([==[
[settings]
maxExpansionDepth = 4

[places.maps]
placeId = 123
maxExpansionDepth = 3

[places.maps.assets]
"game.Workspace.Plain" = "./assets/plain.rbxm"
"game.Workspace.Deep" = { path = "./assets/deep", maxExpansionDepth = 0 }
"workspace.Aliased" = "./assets/aliased.rbxm"

[places.other]
placeId = 456

[places.other.assets]
"game.Workspace.Inherits" = "./assets/inherits"
]==])

		assert(config.places.maps.placeId == 123, "placeId should be read from the place table")
		assert(#config.places.maps.map == 3, "all three mappings should be loaded")

		-- Entry option wins over place, place wins over settings, settings over builtin
		assert(
			entryFor(config, "maps", "game.Workspace.Deep").maxExpansionDepth == 0,
			"per-entry maxExpansionDepth should win"
		)
		assert(
			entryFor(config, "maps", "game.Workspace.Plain").maxExpansionDepth == 3,
			"per-place maxExpansionDepth should win over settings"
		)
		assert(
			entryFor(config, "other", "game.Workspace.Inherits").maxExpansionDepth == 4,
			"settings maxExpansionDepth should apply when a place sets none"
		)

		-- Roblox paths are normalized, and the string form supplies the path
		assert(entryFor(config, "maps", "game.Workspace.Aliased") ~= nil, "workspace. alias should normalize")
		assert(
			entryFor(config, "maps", "game.Workspace.Plain").filesystemPath == "./assets/plain.rbxm",
			"string form should supply the filesystem path"
		)
		assert(
			entryFor(config, "maps", "game.Workspace.Deep").filesystemPath == "./assets/deep",
			"table form should supply the filesystem path"
		)

		-- Mappings are ordered deterministically regardless of TOML table order
		local first = config.places.maps.map[1].robloxPath
		local second = config.places.maps.map[2].robloxPath
		assert(first < second, "entries should be sorted by key")

		-- The builtin default applies with no settings at all
		local bare = load([==[
[places.solo]
placeId = 1

[places.solo.assets]
"game.Workspace.Thing" = "./assets/thing"
]==])
		assert(
			entryFor(bare, "solo", "game.Workspace.Thing").maxExpansionDepth == 2,
			"the built-in default of 2 should apply with no settings"
		)
	end)

	-- A misnamed mapping section must be rejected, not silently dropped
	expectError(
		[==[
[places.maps]
placeId = 123

[places.maps.assets]
"game.Workspace.A" = "./assets/a.rbxm"

[places.maps.instances]
"game.Workspace.B" = "./assets/b.rbxm"
]==],
		"unknown key(s) in places.maps: instances"
	)

	expectError(
		[==[
[places.maps]
placeId = 123
placeID = 456

[places.maps.assets]
"game.Workspace.A" = "./assets/a.rbxm"
]==],
		"placeID"
	)

	expectError(
		[==[
[settings]
maxDepth = 2

[places.maps]
placeId = 123

[places.maps.assets]
"game.Workspace.A" = "./assets/a.rbxm"
]==],
		"unknown key(s) in [settings]: maxDepth"
	)

	expectError(
		[==[
[places.maps]
placeId = 123

[places.maps.assets]
"game.Workspace.A" = { filesystemPath = "./assets/a.rbxm" }
]==],
		"filesystemPath"
	)

	-- Two keys that normalize to the same Roblox path
	expectError(
		[==[
[places.maps]
placeId = 123

[places.maps.assets]
"game.Workspace.Map" = "./assets/a.rbxm"
"workspace.Map" = "./assets/b.rbxm"
]==],
		"twice"
	)

	expectError(
		[==[
[places.maps]
placeId = 123

[places.maps.assets]
"game.Workspace.A" = "./"
]==],
		"cannot target the filesystem root"
	)

	expectError(
		[==[
[places.maps]
placeId = 123

[places.maps.assets]
]==],
		"at least one mapping"
	)

	expectError(
		[==[
[places.maps]
placeId = 123
]==],
		"must contain a [places.maps.assets] table"
	)

	-- The 0.x shape still reports a migration hint rather than a key error
	expectError(
		[==[
[settings]
placeId = 123

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
]==],
		"placefs v0 config"
	)

	if fs.isFile(PATH) then
		fs.removeFile(PATH)
	end

	assert(ok, err)
end
