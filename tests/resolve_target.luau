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
		assert(#targets == 1)
		return targets[1].robloxPaths[1]
	end

	assert(resolveOne("game.Workspace.Story.Level3") == "game.Workspace.Story.Level3")
	assert(resolveOne("workspace.Story.Level3") == "game.Workspace.Story.Level3")
	assert(resolveOne("assets/maps/story/Level3") == "game.Workspace.Story.Level3")
	assert(resolveOne("./assets/maps/story/Level3") == "game.Workspace.Story.Level3")
	assert(resolveOne("assets\\maps\\story\\Level3.rbxm") == "game.Workspace.Story.Level3")
	assert(resolveOne("assets/maps/Lobby.rbxm") == "game.Workspace.Lobby")
	assert(resolveOne("assets/maps/story/special/Child") == "game.Workspace.Special.Child")

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
	assert(#allTargets == 2)
	assert(allTargets[1].placeName == "alpha")
	assert(allTargets[2].placeName == "maps")
	assert(#allTargets[2].robloxPaths == 3)
end
