local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Types = require("./Types")

local function validate_asset_map_entry(entry: Types.AssetMapEntry)
	assert(typeof(entry.robloxPath) == "string", "robloxPath must be a string")
	assert(typeof(entry.filesystemPath) == "string", "filesystemPath must be a string")

	if entry.maxExpansionDepth ~= nil then
		assert(
			typeof(entry.maxExpansionDepth) == "number"
				and entry.maxExpansionDepth >= 0
				and math.floor(entry.maxExpansionDepth) == entry.maxExpansionDepth,
			"maxExpansionDepth must be a non-negative integer if provided"
		)
	end
end

--- Loads and validates an asset map from the given path.
return function(path: string)
	-- Check if the file exists
	if not fs.isFile(path) then
		error("Config file does not exist at path: " .. path)
	end

	-- Read and parse the config
	local content = serde.decode("toml", fs.readFile(path))

	-- Validating the structure of the config
	if typeof(content.settings) ~= "table" then
		error("Invalid config: missing [settings] section")
	end

	if typeof(content.settings.placeId) ~= "number" then
		error(`Invalid config: settings.placeId must be a number, got {tostring(content.settings.placeId)}`)
	end

	if typeof(content.assets) ~= "table" then
		error("Invalid config: missing [[assets]] entries")
	end

	for _, asset in content.assets do
		validate_asset_map_entry(asset)
	end

	-- Return as SyncConfig structure
	return {
		placeId = content.settings.placeId,
		map = content.assets,
	} :: Types.SyncConfig
end
