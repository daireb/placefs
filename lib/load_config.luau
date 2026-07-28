local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Types = require("./Types")
local normalizeRobloxPath = require("./normalize_path")

local DEFAULT_MAX_EXPANSION_DEPTH = 2

local function validateMaxExpansionDepth(value: any, path: string)
	if value == nil then
		return
	end

	assert(
		typeof(value) == "number" and value >= 0 and math.floor(value) == value,
		`Invalid config: {path} must be a non-negative integer`
	)
end

local function validateAssetMapEntry(entry: any, path: string)
	assert(typeof(entry) == "table", `Invalid config: {path} must be a table`)
	assert(typeof(entry.robloxPath) == "string", `Invalid config: {path}.robloxPath must be a string`)
	assert(typeof(entry.filesystemPath) == "string", `Invalid config: {path}.filesystemPath must be a string`)
	local normalizedFilesystemPath = entry.filesystemPath:gsub("\\", "/"):gsub("/+$", "")
	assert(
		normalizedFilesystemPath ~= ""
			and normalizedFilesystemPath ~= "."
			and normalizedFilesystemPath ~= "/"
			and normalizedFilesystemPath:match("^%a:$") == nil,
		`Invalid config: {path}.filesystemPath cannot target the filesystem root`
	)
	validateMaxExpansionDepth(entry.maxExpansionDepth, `{path}.maxExpansionDepth`)

	entry.robloxPath = normalizeRobloxPath(entry.robloxPath)
end

--- Loads and validates a multi-place configuration from the given path.
return function(path: string): Types.Config
	if not fs.isFile(path) then
		error("Config file does not exist at path: " .. path)
	end

	local content = serde.decode("toml", fs.readFile(path))
	assert(typeof(content) == "table", "Invalid config: expected a TOML table")

	if content.assets ~= nil or (typeof(content.settings) == "table" and content.settings.placeId ~= nil) then
		error(
			"This is a placefs v0 config. Places now live under [places.<name>]. "
				.. "See CHANGELOG.md for migration instructions."
		)
	end

	local settings = content.settings or {}
	assert(typeof(settings) == "table", "Invalid config: [settings] must be a table")
	validateMaxExpansionDepth(settings.maxExpansionDepth, "settings.maxExpansionDepth")

	assert(typeof(content.places) == "table", "Invalid config: missing [places.<name>] sections")
	assert(next(content.places) ~= nil, "Invalid config: at least one place is required")

	local places: { [string]: Types.SyncConfig } = {}

	for placeName, place in content.places do
		local placePath = `places.{placeName}`
		assert(
			placeName:match("^[%w][%w_-]*$") ~= nil,
			`Invalid config: place name '{placeName}' may only contain letters, numbers, hyphens, and underscores`
		)
		assert(typeof(place) == "table", `Invalid config: {placePath} must be a table`)
		assert(
			typeof(place.placeId) == "number"
				and place.placeId > 0
				and math.floor(place.placeId) == place.placeId,
			`Invalid config: {placePath}.placeId must be a positive integer`
		)
		validateMaxExpansionDepth(place.maxExpansionDepth, `{placePath}.maxExpansionDepth`)
		assert(
			typeof(place.assets) == "table" and #place.assets > 0,
			`Invalid config: {placePath} must contain at least one [[{placePath}.assets]] entry`
		)

		local map: Types.AssetMap = {}
		for index, asset in place.assets do
			local assetPath = `{placePath}.assets[{index}]`
			validateAssetMapEntry(asset, assetPath)
			asset.maxExpansionDepth = asset.maxExpansionDepth
				or place.maxExpansionDepth
				or settings.maxExpansionDepth
				or DEFAULT_MAX_EXPANSION_DEPTH
			table.insert(map, asset :: Types.AssetMapEntry)
		end

		places[placeName] = {
			placeId = place.placeId,
			map = map,
		}
	end

	return {
		settings = {
			maxExpansionDepth = settings.maxExpansionDepth,
		},
		places = places,
	}
end
