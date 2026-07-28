local resolveTarget = require("../lib/resolve_target")

local function expectError(callback, expected: string)
	local ok, message = pcall(callback)
	assert(not ok, "Expected callback to fail")
	assert(
		tostring(message):find(expected, 1, true),
		`Expected error containing '{expected}', got '{tostring(message)}'`
	)
end

local config = {
	settings = {},
	places = {
		maps = {
			placeId = 1,
			map = {
				{
					robloxPath = "game.Workspace.Story",
					filesystemPath = "./assets/maps/story",
					maxExpansionDepth = 2,
				},
				{
					robloxPath = "game.Workspace.Special",
					filesystemPath = "./assets/maps/story/special",
					maxExpansionDepth = 2,
				},
				{
					robloxPath = "game.Workspace.Lobby",
					filesystemPath = "./assets/maps/Lobby.rbxm",
					maxExpansionDepth = 0,
				},
			},
		},
		alpha = {
			placeId = 2,
			map = {
				{
					robloxPath = "game.ReplicatedStorage.Asset",
					filesystemPath = "./assets/shared.rbxm",
					maxExpansionDepth = 0,
				},
			},
		},
	},
}

return function()
	local function resolveOne(path: string): string
		local targets = resolveTarget(config, {
			place = "maps",
			positionals = { path },
			all = false,
		})
		assert(#targets == 1, `Expected exactly one target for '{path}'`)
		return targets[1].robloxPaths[1]
	end

	assert(
		resolveOne("game.Workspace.Story.Level3") == "game.Workspace.Story.Level3",
		"a game. positional should pass through as a Roblox path"
	)
	assert(
		resolveOne("workspace.Story.Level3") == "game.Workspace.Story.Level3",
		"a workspace. positional should normalize to a full Roblox path"
	)
	assert(
		resolveOne("assets/maps/story/Level3") == "game.Workspace.Story.Level3",
		"a filesystem path should map back to its Roblox path"
	)
	assert(resolveOne("./assets/maps/story/Level3") == "game.Workspace.Story.Level3", "a leading ./ should be ignored")
	assert(
		resolveOne("assets\\maps\\story\\Level3.rbxm") == "game.Workspace.Story.Level3",
		"backslashes and a model extension should be normalized away"
	)
	assert(
		resolveOne("assets/maps/Lobby.rbxm") == "game.Workspace.Lobby",
		"an exact single-file mapping should resolve"
	)
	assert(
		resolveOne("assets/maps/story/special/Child") == "game.Workspace.Special.Child",
		"the most specific mapping should win over a shorter prefix"
	)

	expectError(function()
		resolveOne("assets/maps/storybook/Level3")
	end, "No mapping")

	expectError(function()
		resolveTarget(config, {
			place = "missing",
			positionals = {},
			all = true,
		})
	end, "Unknown place")

	expectError(function()
		resolveTarget(config, {
			place = nil,
			positionals = { "assets/maps/story" },
			all = false,
		})
	end, "--place is required")

	local allTargets = resolveTarget(config, {
		place = nil,
		positionals = {},
		all = true,
	})
	assert(#allTargets == 2, "--all with no place should target every place")
	assert(allTargets[1].placeName == "alpha", "places should be iterated in sorted name order")
	assert(allTargets[2].placeName == "maps", "places should be iterated in sorted name order")
	assert(#allTargets[2].robloxPaths == 3, "--all should cover every mapping in the place")

	-- A single configured place needs no --place to disambiguate
	local soleConfig = {
		settings = {},
		places = { only = config.places.alpha },
	}

	local soleTargets = resolveTarget(soleConfig, {
		place = nil,
		positionals = { "assets/shared.rbxm" },
		all = false,
	})
	assert(#soleTargets == 1, "the sole place should resolve without --place")
	assert(soleTargets[1].placeName == "only", "the sole place should be selected by name")
	assert(
		soleTargets[1].robloxPaths[1] == "game.ReplicatedStorage.Asset",
		"a filesystem target should resolve against the sole place"
	)

	-- An explicitly wrong name still errors, even with only one place
	expectError(function()
		resolveTarget(soleConfig, {
			place = "typo",
			positionals = {},
			all = true,
		})
	end, "Unknown place")
end
