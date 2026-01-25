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
		error("Asset map file does not exist at path: " .. path)
	end

	-- Read and parse the asset map
	local content = serde.decode("json", fs.readFile(path)) :: Types.SyncConfig

	-- Validating the structure of the asset map
	if typeof(content.placeId) ~= "number" then
		error(`Invalid asset map: placeId must be a number, got {tostring(content.placeId)}`)
	end

	for _, asset in content.map do
		validate_asset_map_entry(asset)
	end

	-- Return the validated content
	return content
end
