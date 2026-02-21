local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Types = require("./Types")
local load_sync_config = require("./load_sync_config")

local DEFAULT_CONFIG_PATH = "placefs.toml"
local OUTPUT_FILENAME = "placefs.project.json"

local SERVICES: { [string]: boolean } = {
	Workspace = true,
	ReplicatedStorage = true,
	ReplicatedFirst = true,
	ServerScriptService = true,
	ServerStorage = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Lighting = true,
	SoundService = true,
	Chat = true,
	Teams = true,
	TextChatService = true,
}

--- Builds a Rojo project tree from an asset map.
--- Each asset entry's robloxPath is split into segments and nested into
--- the tree, with the final segment receiving a $path pointing to the
--- filesystem location.
local function buildTree(assetMap: Types.AssetMap): { [string]: any }
	local tree: { [string]: any } = { ["$className"] = "DataModel" }

	for _, entry in assetMap do
		local segments = entry.robloxPath:split(".")
		local current = tree

		for i = 2, #segments do
			local segment = segments[i]
			local isLast = (i == #segments)

			if current[segment] == nil then
				current[segment] = {}
			end

			if i == 2 and SERVICES[segment] then
				current[segment]["$className"] = segment
			elseif not isLast and current[segment]["$className"] == nil and current[segment]["$path"] == nil then
				current[segment]["$className"] = "Folder"
			end

			if isLast then
				current[segment]["$path"] = entry.filesystemPath
				-- Rojo errors when $className and $path both point to a file,
				-- since the file already carries class information.
				-- Only directories (folder expansion) can coexist with $className.
				local isFilePath = entry.filesystemPath:sub(-5) == ".rbxm"
					or entry.filesystemPath:sub(-6) == ".rbxmx"
				if isFilePath then
					current[segment]["$className"] = nil
				end
			else
				current = current[segment]
			end
		end
	end

	return tree
end

--- Generates a Rojo project file from the placefs configuration.
return function(configPath: string?)
	local resolvedConfigPath = process.cwd .. (configPath or DEFAULT_CONFIG_PATH)
	local config = load_sync_config(resolvedConfigPath)

	local project = {
		name = "placefs",
		tree = buildTree(config.map),
	}

	local json = serde.encode("json", project, true)
	local outputPath = process.cwd .. OUTPUT_FILENAME

	fs.writeFile(outputPath, json)
	print(`[placefs] Generated {OUTPUT_FILENAME}`)
end
