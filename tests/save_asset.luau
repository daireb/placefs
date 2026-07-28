local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local saveAsset = require("../lib/save_asset")

local DRY_RUN = { dryRun = true, quiet = true }

--- Builds a DataModel with `game.Workspace.Maps` containing the given child names.
local function buildGame(childNames: { string }): roblox.DataModel
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")

	local maps = roblox.Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = workspace

	for _, name in childNames do
		local child = roblox.Instance.new("Folder")
		child.Name = name
		child.Parent = maps
	end

	return game
end

local function expectSaveError(childNames: { string }, expected: string)
	local game = buildGame(childNames)
	local ok, message = pcall(saveAsset, game, "game.Workspace.Maps", "/tmp/placefs-should-not-exist", 2, DRY_RUN)

	assert(not ok, `Expected child name '{childNames[1]}' to be rejected`)
	assert(
		tostring(message):find(expected, 1, true),
		`Expected error containing '{expected}', got '{tostring(message)}'`
	)
end

return function()
	-- Names that cannot round-trip through the filesystem are rejected
	expectSaveError({ "a/b" }, "path separator")
	expectSaveError({ "a\\b" }, "path separator")
	expectSaveError({ "Level1.rbxm" }, "model extension")
	expectSaveError({ "Level1.RBXMX" }, "model extension")
	expectSaveError({ "Same", "Same" }, "duplicate names")

	-- Ordinary names pass, and a dry run writes nothing
	local target = "/tmp/placefs-dryrun-target"
	assert(not fs.isDir(target), "test target should not exist beforehand")

	local game = buildGame({ "Level1", "Level2" })
	saveAsset(game, "game.Workspace.Maps", target, 2, DRY_RUN)
	assert(not fs.isDir(target), "dry run must not create directories")

	-- A dotted name is only a warning, so the save still succeeds
	local dotted = buildGame({ "My.Model" })
	saveAsset(dotted, "game.Workspace.Maps", target, 2, DRY_RUN)
	assert(not fs.isDir(target), "dry run must not create directories")

	-- Validation covers nested folders, not just direct children
	local nested = roblox.Instance.new("DataModel")
	local nestedMaps = roblox.Instance.new("Folder")
	nestedMaps.Name = "Maps"
	nestedMaps.Parent = nested:GetService("Workspace")
	local level = roblox.Instance.new("Folder")
	level.Name = "Level1"
	level.Parent = nestedMaps
	local deep = roblox.Instance.new("Folder")
	deep.Name = "bad/name"
	deep.Parent = level

	local ok, message = pcall(saveAsset, nested, "game.Workspace.Maps", target, 3, DRY_RUN)
	assert(not ok, "nested invalid name should be rejected")
	assert(tostring(message):find("path separator", 1, true))

	-- A non-Folder cannot expand into a directory
	local part = roblox.Instance.new("DataModel")
	local model = roblox.Instance.new("Model")
	model.Name = "Maps"
	model.Parent = part:GetService("Workspace")

	local okPart, partMessage = pcall(saveAsset, part, "game.Workspace.Maps", target, 2, DRY_RUN)
	assert(not okPart, "non-Folder should not expand")
	assert(tostring(partMessage):find("Cannot save non-Folder instance", 1, true))
end
