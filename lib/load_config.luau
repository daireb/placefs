local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Types = require("./Types")
local normalizeRobloxPath = require("./normalize_path")

local DEFAULT_MAX_EXPANSION_DEPTH = 2

local TOP_LEVEL_KEYS = { settings = true, places = true, packages = true }
local SETTINGS_KEYS = { maxExpansionDepth = true }
local PLACE_KEYS = { placeId = true, maxExpansionDepth = true, assets = true }
local PACKAGE_KEYS = { packageId = true, version = true, maxExpansionDepth = true, assets = true }
local ASSET_KEYS = { path = true, maxExpansionDepth = true }

local function sortedKeys(tbl: { [string]: any }): { string }
	local names = {}
	for name in tbl do
		table.insert(names, tostring(name))
	end
	table.sort(names)
	return names
end

--- Rejects keys the loader does not understand, so a misnamed section is a
--- loud error rather than a mapping that silently never syncs.
local function rejectUnknownKeys(tbl: { [string]: any }, allowed: { [string]: boolean }, context: string)
	local unknown = {}
	for key in tbl do
		if not allowed[key] then
			table.insert(unknown, tostring(key))
		end
	end

	if #unknown > 0 then
		table.sort(unknown)
		error(
			`Invalid config: unknown key(s) in {context}: {table.concat(unknown, ", ")}. `
				.. `Valid keys: {table.concat(sortedKeys(allowed), ", ")}`
		)
	end
end

local function validateMaxExpansionDepth(value: any, context: string)
	if value == nil then
		return
	end

	assert(
		typeof(value) == "number" and value >= 0 and math.floor(value) == value,
		`Invalid config: {context} must be a non-negative integer`
	)
end

local function validateFilesystemPath(value: string, context: string)
	local normalized = value:gsub("\\", "/"):gsub("/+$", "")
	assert(
		normalized ~= "" and normalized ~= "." and normalized ~= "/" and normalized:match("^%a:$") == nil,
		`Invalid config: {context} cannot target the filesystem root`
	)
end

--- Reads one asset mapping, which is either a filesystem path string or a
--- table carrying per-entry options.
local function parseAssetEntry(value: any, context: string): (string, number?)
	if typeof(value) == "string" then
		validateFilesystemPath(value, context)
		return value, nil
	end

	assert(
		typeof(value) == "table",
		`Invalid config: {context} must be a filesystem path string, or a table with a 'path' key`
	)
	rejectUnknownKeys(value, ASSET_KEYS, context)
	assert(typeof(value.path) == "string", `Invalid config: {context}.path must be a string`)
	validateFilesystemPath(value.path, `{context}.path`)
	validateMaxExpansionDepth(value.maxExpansionDepth, `{context}.maxExpansionDepth`)

	return value.path, value.maxExpansionDepth
end

local function validatePositiveInteger(value: any, context: string)
	assert(
		typeof(value) == "number" and value > 0 and math.floor(value) == value,
		`Invalid config: {context} must be a positive integer`
	)
end

--- Reads a [places.<name>] or [packages.<name>] section; `kind` is "place" or "package".
local function parseSource(kind: string, name: string, source: any, settingsDepth: number?): Types.SyncConfig
	local isPackage = kind == "package"
	local context = `{if isPackage then "packages" else "places"}.{name}`

	assert(
		name:match("^[%w][%w_-]*$") ~= nil,
		`Invalid config: {kind} name '{name}' may only contain letters, numbers, hyphens, and underscores`
	)
	assert(typeof(source) == "table", `Invalid config: {context} must be a table`)
	rejectUnknownKeys(source, if isPackage then PACKAGE_KEYS else PLACE_KEYS, context)

	if isPackage then
		validatePositiveInteger(source.packageId, `{context}.packageId`)
		if source.version ~= nil then
			validatePositiveInteger(source.version, `{context}.version`)
		end
	else
		validatePositiveInteger(source.placeId, `{context}.placeId`)
	end
	validateMaxExpansionDepth(source.maxExpansionDepth, `{context}.maxExpansionDepth`)

	assert(typeof(source.assets) == "table", `Invalid config: {context} must contain a [{context}.assets] table`)

	local robloxPaths = sortedKeys(source.assets)
	assert(#robloxPaths > 0, `Invalid config: [{context}.assets] must contain at least one mapping`)

	local map: Types.AssetMap = {}
	local seen: { [string]: string } = {}

	for _, rawPath in robloxPaths do
		local entryContext = `{context}.assets."{rawPath}"`
		local filesystemPath, entryDepth = parseAssetEntry(source.assets[rawPath], entryContext)

		local robloxPath = normalizeRobloxPath(rawPath)
		if isPackage and robloxPath:sub(1, 5) == "game." then
			error(
				`Invalid config: {entryContext} starts with 'game.', but a package's paths start at the `
					.. 'package\'s own instance, such as "Materials" or "Materials.Grass"'
			)
		end
		if seen[robloxPath] then
			error(`Invalid config: {context} maps '{robloxPath}' twice, as '{seen[robloxPath]}' and '{rawPath}'`)
		end
		seen[robloxPath] = rawPath

		table.insert(map, {
			robloxPath = robloxPath,
			filesystemPath = filesystemPath,
			maxExpansionDepth = entryDepth or source.maxExpansionDepth or settingsDepth or DEFAULT_MAX_EXPANSION_DEPTH,
		})
	end

	return {
		placeId = if isPackage then nil else source.placeId,
		packageId = if isPackage then source.packageId else nil,
		version = if isPackage then source.version else nil,
		map = map,
	}
end

--- Loads and validates a multi-place configuration from the given path.
return function(path: string): Types.Config
	if not fs.isFile(path) then
		error("Config file does not exist at path: " .. path)
	end

	local content = serde.decode("toml", fs.readFile(path))
	assert(typeof(content) == "table", "Invalid config: expected a TOML table")

	-- Detect the 0.x shape before key validation, so it gets a migration hint
	if content.assets ~= nil or (typeof(content.settings) == "table" and content.settings.placeId ~= nil) then
		error(
			"This is a placefs v0 config. Places now live under [places.<name>]. "
				.. "See CHANGELOG.md for migration instructions."
		)
	end

	rejectUnknownKeys(content, TOP_LEVEL_KEYS, "the config root")

	local settings = content.settings or {}
	assert(typeof(settings) == "table", "Invalid config: [settings] must be a table")
	rejectUnknownKeys(settings, SETTINGS_KEYS, "[settings]")
	validateMaxExpansionDepth(settings.maxExpansionDepth, "settings.maxExpansionDepth")

	local rawPlaces = content.places or {}
	local rawPackages = content.packages or {}
	assert(typeof(rawPlaces) == "table", "Invalid config: [places] must contain [places.<name>] sections")
	assert(typeof(rawPackages) == "table", "Invalid config: [packages] must contain [packages.<name>] sections")
	assert(
		next(rawPlaces) ~= nil or next(rawPackages) ~= nil,
		"Invalid config: at least one [places.<name>] or [packages.<name>] section is required"
	)

	local places: { [string]: Types.SyncConfig } = {}
	for placeName, place in rawPlaces do
		places[placeName] = parseSource("place", placeName, place, settings.maxExpansionDepth)
	end

	local packages: { [string]: Types.SyncConfig } = {}
	for packageName, package in rawPackages do
		-- One name selects one source on the command line
		if places[packageName] ~= nil then
			error(`Invalid config: '{packageName}' names both a place and a package`)
		end
		packages[packageName] = parseSource("package", packageName, package, settings.maxExpansionDepth)
	end

	return {
		settings = {
			maxExpansionDepth = settings.maxExpansionDepth,
		},
		places = places,
		packages = packages,
	}
end
