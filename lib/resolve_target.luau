local Types = require("./Types")
local normalizeRobloxPath = require("./normalize_path")

export type ResolveOptions = {
	place: string?,
	positionals: { string },
	all: boolean,
}

--- Places and packages by name; the loader keeps their names distinct.
local function allSources(config: Types.Config): { [string]: Types.SyncConfig }
	local sources = table.clone(config.places)
	for name, package in config.packages do
		sources[name] = package
	end
	return sources
end

local function sortedNames(sources: { [string]: Types.SyncConfig }): { string }
	local names = {}
	for name in sources do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function normalizeFilesystemPath(path: string): string
	local normalized = path:gsub("\\", "/")
	while normalized:sub(1, 2) == "./" do
		normalized = normalized:sub(3)
	end
	normalized = normalized:gsub("/+$", "")

	local lower = normalized:lower()
	if lower:sub(-6) == ".rbxmx" then
		normalized = normalized:sub(1, -7)
	elseif lower:sub(-5) == ".rbxm" then
		normalized = normalized:sub(1, -6)
	end

	return normalized
end

local function isFilesystemPrefix(root: string, target: string): boolean
	return target == root or target:sub(1, #root + 1) == root .. "/"
end

local function resolveFilesystemPath(syncConfig: Types.SyncConfig, path: string): string
	local normalizedPath = normalizeFilesystemPath(path)
	local bestEntry: Types.AssetMapEntry? = nil
	local bestRoot: string? = nil

	for _, entry in syncConfig.map do
		local root = normalizeFilesystemPath(entry.filesystemPath)
		if isFilesystemPrefix(root, normalizedPath) and (bestRoot == nil or #root > #bestRoot) then
			bestEntry = entry
			bestRoot = root
		end
	end

	if bestEntry == nil or bestRoot == nil then
		error(`No mapping in the selected place matches filesystem path: '{path}'`)
	end

	local relativePath = normalizedPath:sub(#bestRoot + 1)
	if relativePath:sub(1, 1) == "/" then
		relativePath = relativePath:sub(2)
	end

	if relativePath == "" then
		return bestEntry.robloxPath
	end

	return bestEntry.robloxPath .. "." .. table.concat(relativePath:split("/"), ".")
end

--- A package's Roblox paths have no `game.` to tell them apart, so they are the ones inside a mapping.
local function isPackageRobloxPath(syncConfig: Types.SyncConfig, path: string): boolean
	for _, entry in syncConfig.map do
		if path == entry.robloxPath or path:sub(1, #entry.robloxPath + 1) == entry.robloxPath .. "." then
			return true
		end
	end
	return false
end

local function resolvePositionals(syncConfig: Types.SyncConfig, positionals: { string }): { string }
	local paths = {}

	for _, path in positionals do
		local isRobloxPath = if syncConfig.packageId ~= nil
			then isPackageRobloxPath(syncConfig, path)
			else path:sub(1, 5) == "game." or path:sub(1, 10) == "workspace."
		if isRobloxPath then
			table.insert(paths, normalizeRobloxPath(path))
		else
			table.insert(paths, resolveFilesystemPath(syncConfig, path))
		end
	end

	return paths
end

local function allMappedPaths(syncConfig: Types.SyncConfig): { string }
	local paths = {}
	for _, entry in syncConfig.map do
		table.insert(paths, entry.robloxPath)
	end
	return paths
end

--- Resolves CLI selection and positional paths without performing any I/O.
return function(config: Types.Config, options: ResolveOptions): { Types.ResolvedTarget }
	if options.all and #options.positionals > 0 then
		error("Cannot combine --all with positional paths")
	end

	local sources = allSources(config)
	local placeNames = sortedNames(sources)

	-- With a single configured place or package there is nothing to disambiguate
	local selected = options.place or (if #placeNames == 1 then placeNames[1] else nil)

	if selected ~= nil then
		local syncConfig = sources[selected]
		if syncConfig == nil then
			error(`Unknown place or package '{selected}'. Configured: {table.concat(placeNames, ", ")}`)
		end

		if not options.all and #options.positionals == 0 then
			error("No instances specified. Use --all or provide Roblox/filesystem paths.")
		end

		return {
			{
				placeName = selected,
				syncConfig = syncConfig,
				robloxPaths = if options.all
					then allMappedPaths(syncConfig)
					else resolvePositionals(syncConfig, options.positionals),
			},
		}
	end

	if not options.all then
		if #options.positionals > 0 then
			error(`--place is required when syncing positional paths. Configured: {table.concat(placeNames, ", ")}`)
		end
		error("No instances specified. Use --all or provide --place with Roblox/filesystem paths.")
	end

	local targets = {}
	for _, placeName in placeNames do
		local syncConfig = sources[placeName]
		table.insert(targets, {
			placeName = placeName,
			syncConfig = syncConfig,
			robloxPaths = allMappedPaths(syncConfig),
		})
	end

	return targets
end
