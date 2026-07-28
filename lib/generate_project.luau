local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Types = require("./Types")
local load_config = require("./load_config")
local resolveFilesystemPath = require("./resolve_filesystem_path")

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

local function writeProject(placeName: string, syncConfig: Types.SyncConfig, outputFilename: string)
	local project = {
		name = placeName,
		tree = buildTree(syncConfig.map),
	}

	local json = serde.encode("json", project, true)
	local fullOutputPath = resolveFilesystemPath(outputFilename)

	fs.writeFile(fullOutputPath, json)
	print(`[placefs] Generated {outputFilename}`)
end

--- Generates one or all Rojo project files from the placefs configuration.
--- @param configPath Path to the config file (from --config)
--- @param placeName Optional configured place name (from --place)
--- @param outputPath Optional explicit output path (from --output)
return function(configPath: string, placeName: string?, outputPath: string?)
	local config = load_config(resolveFilesystemPath(configPath))
	local placeNames = {}

	if placeName ~= nil then
		if config.places[placeName] == nil then
			error(`Unknown place '{placeName}'. Run 'placefs places' to list configured places.`)
		end
		table.insert(placeNames, placeName)
	else
		for name in config.places do
			table.insert(placeNames, name)
		end
		table.sort(placeNames)
	end

	if outputPath ~= nil and #placeNames > 1 then
		error("--output requires --place when the config contains multiple places")
	end

	for _, name in placeNames do
		writeProject(name, config.places[name], outputPath or (name .. ".project.json"))
	end
end
