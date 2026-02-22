local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Types = require("./Types")
local load_sync_config = require("./load_sync_config")

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

--- Extracts the base name from a config path by stripping directory and .toml extension.
--- e.g. "placefs.toml" -> "placefs", "configs/builder.toml" -> "builder"
local function deriveBaseName(configPath: string): string
	local filename = configPath:match("([^/\\]+)$") or configPath
	return filename:match("(.+)%.toml$") or filename
end

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
--- @param configPath Path to the config file (from --config)
--- @param outputPath Optional explicit output path (from --output); derived from config name if nil
return function(configPath: string, outputPath: string?)
	local resolvedConfigPath = process.cwd .. configPath
	local config = load_sync_config(resolvedConfigPath)

	local baseName = deriveBaseName(configPath)
	local outputFilename = outputPath or (baseName .. ".project.json")

	local project = {
		name = baseName,
		tree = buildTree(config.map),
	}

	local json = serde.encode("json", project, true)
	local fullOutputPath = process.cwd .. outputFilename

	fs.writeFile(fullOutputPath, json)
	print(`[placefs] Generated {outputFilename}`)
end
