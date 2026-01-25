local roblox = require("@lune/roblox")

local Types = require("./Types")

local download_place = require("./download_place")
local get_auth_cookie = require("./get_auth_cookie")
local save_asset = require("./save_asset")

local DEFAULT_MAX_EXPANSION_DEPTH = 2

--- Checks if a filesystem path has a model file extension.
local function hasModelExtension(path: string): boolean
	return path:sub(-5) == ".rbxm" or path:sub(-6) == ".rbxmx"
end

--- Gets the effective max expansion depth for an entry.
--- If the filesystem path has a model extension, depth is 0 (no expansion).
local function getEffectiveMaxDepth(entry: Types.AssetMapEntry): number
	if hasModelExtension(entry.filesystemPath) then
		return 0
	end
	return entry.maxExpansionDepth or DEFAULT_MAX_EXPANSION_DEPTH
end

--- Builds a lookup table of known Roblox instance paths to their full entries.
local function buildEntryLookup(asset_map: Types.AssetMap): { [string]: Types.AssetMapEntry }
	local lookup = {}

	for _, entry in asset_map do
		lookup[entry.robloxPath] = entry
	end

	return lookup
end

--- Finds the nearest known ancestor entry for a given Roblox path.
local function findAncestorEntry(
	entryLookup: { [string]: Types.AssetMapEntry },
	robloxPath: string
): Types.AssetMapEntry?
	local pathSegments = robloxPath:split(".")

	while #pathSegments > 0 do
		local currentPath = table.concat(pathSegments, ".")
		if entryLookup[currentPath] ~= nil then
			return entryLookup[currentPath]
		end

		table.remove(pathSegments)
	end

	return nil
end

--- Extracts relative path segments from an ancestor path to a target path.
--- Example: getRelativeSegments("game.Workspace.Parts", "game.Workspace.Parts.Gun.Handle")
---          returns {"Gun", "Handle"}
local function getRelativeSegments(ancestorPath: string, targetPath: string): { string }
	-- Remove the ancestor prefix plus the dot separator
	local relativePath = targetPath:sub(#ancestorPath + 2) -- +2 for the trailing dot
	if relativePath == "" then
		return {}
	end
	return relativePath:split(".")
end

--- Resolves an instance from a Roblox path, returning the DataModel root for further traversal.
local function resolveRootInstance(game: roblox.DataModel, robloxPath: string): (roblox.Instance, string)
	if robloxPath:sub(1, 5) == "game." then
		return game, robloxPath:sub(6)
	elseif robloxPath:sub(1, 10) == "workspace." then
		local workspace = game:FindFirstChild("Workspace")
		if workspace == nil then
			error("Workspace not found in DataModel")
		end
		return workspace, robloxPath:sub(11)
	end

	error(`Invalid Roblox path: '{robloxPath}'. Path must start with 'game.' or 'workspace.'`)
end

--- Resolves an instance from the given parent using a dot-separated path.
local function resolveFromParent(parent: roblox.Instance, path: string): roblox.Instance?
	if path == "" then
		return parent
	end

	local segments = path:split(".")
	local current: roblox.Instance? = parent

	for _, segment in segments do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(segment)
	end

	return current
end

--- Validates that a target path is reachable (not inside a serialized file).
--- Walks from the mapping root to the target, checking each intermediate instance.
--- @param game The Roblox DataModel
--- @param ancestorPath The Roblox path of the mapping entry (e.g., "game.Workspace.Parts")
--- @param relativeSegments The path segments from ancestor to target (e.g., {"Gun", "Handle"})
--- @param maxDepth The effective max expansion depth for this entry
--- @return The resolved target instance if reachable
local function validateAndResolveTarget(
	game: roblox.DataModel,
	ancestorPath: string,
	relativeSegments: { string },
	maxDepth: number
): roblox.Instance
	local rootInstance, remainingPath = resolveRootInstance(game, ancestorPath)
	local ancestorInstance = resolveFromParent(rootInstance, remainingPath)

	if ancestorInstance == nil then
		error(`Instance not found at mapping path: '{ancestorPath}'`)
	end

	local currentInstance = ancestorInstance
	local currentPath = ancestorPath

	for i, segment in relativeSegments do
		local depth = i -- First child is depth 1
		local isLastSegment = (i == #relativeSegments)

		-- Try to find the child
		local childInstance = currentInstance:FindFirstChild(segment)
		if childInstance == nil then
			error(`Instance not found at path: '{currentPath}.{segment}'`)
		end

		if not isLastSegment then
			-- This is an intermediate instance on the path to target
			-- Check if it's a Folder that gets expanded
			if childInstance.ClassName ~= "Folder" then
				-- Non-folder at intermediate position - target is inside this serialized file
				error(
					`Cannot update '{table.concat(relativeSegments, ".")}' - it is contained within '{segment}.rbxm' (non-Folder instance)`
				)
			end

			if depth >= maxDepth then
				-- Folder at or beyond expansion limit - it's serialized as a file
				error(
					`Cannot update '{table.concat(relativeSegments, ".")}' - it is contained within '{segment}.rbxm' (expansion depth exceeded)`
				)
			end
		end

		currentInstance = childInstance
		currentPath = currentPath .. "." .. segment
	end

	return currentInstance
end

--- Builds the filesystem path for a target within an expanded folder structure.
--- @param baseFilesystemPath The filesystem path of the mapping entry
--- @param relativeSegments The path segments from ancestor to target
--- @param targetInstance The resolved target instance
--- @param targetDepth The depth of the target (number of segments from ancestor)
--- @param maxDepth The effective max expansion depth
--- @return The filesystem path for the target
local function buildTargetFilesystemPath(
	baseFilesystemPath: string,
	relativeSegments: { string },
	targetInstance: roblox.Instance,
	targetDepth: number,
	maxDepth: number
): string
	-- Start with the base path (which is a directory for expanded folders)
	local path = baseFilesystemPath

	-- Add each segment as a directory, except possibly the last one
	for i, segment in relativeSegments do
		path = path .. "/" .. segment
	end

	-- Determine if target should be a file or directory
	local isFolder = targetInstance.ClassName == "Folder"
	local wouldExpand = isFolder and targetDepth < maxDepth

	if not wouldExpand then
		-- Target becomes a file
		path = path .. ".rbxm"
	end
	-- If it would expand, path stays as a directory (saveRecursive will handle it)

	return path
end

return function(syncConfig: Types.SyncConfig, instancesToUpdate: { string })
	local entryLookup = buildEntryLookup(syncConfig.map)

	-- Check for any overlapping entries in assetMap
	for _, entry in syncConfig.map do
		local ancestor = findAncestorEntry(entryLookup, entry.robloxPath)
		if ancestor and ancestor.robloxPath ~= entry.robloxPath then
			error(
				`Asset map contains overlapping entries: '{entry.robloxPath}' overlaps with known ancestor '{ancestor.robloxPath}'`
			)
		end
	end

	-- Check for duplicates/overlaps in instancesToUpdate
	local instancesToUpdateLookup: { [string]: boolean } = {}
	for _, robloxPath in instancesToUpdate do
		if instancesToUpdateLookup[robloxPath] then
			error(`Duplicate instance path in instancesToUpdate: '{robloxPath}'`)
		end

		-- Check if this path overlaps with an already-queued path
		local pathSegments = robloxPath:split(".")
		while #pathSegments > 0 do
			local currentPath = table.concat(pathSegments, ".")
			if currentPath ~= robloxPath and instancesToUpdateLookup[currentPath] then
				error(`Instance path '{robloxPath}' overlaps with already-queued path '{currentPath}'`)
			end
			table.remove(pathSegments)
		end

		instancesToUpdateLookup[robloxPath] = true
	end

	-- Download place from Roblox
	local auth_cookie = get_auth_cookie()
	local game = download_place(syncConfig.placeId, auth_cookie)

	-- Save each requested instance
	print(string.format("[placefs] Updating %i instances...", #instancesToUpdate))

	for _, targetRobloxPath in instancesToUpdate do
		local entry = findAncestorEntry(entryLookup, targetRobloxPath)
		if entry == nil then
			print(`[placefs] No known mapping found for instance path: '{targetRobloxPath}', skipping.`)
			continue
		end

		local effectiveMaxDepth = getEffectiveMaxDepth(entry)

		if targetRobloxPath == entry.robloxPath then
			-- Exact match: save the whole mapping
			print(`[placefs] Saving: {entry.robloxPath} -> {entry.filesystemPath}`)
			save_asset(game, entry.robloxPath, entry.filesystemPath, effectiveMaxDepth)
		else
			-- Targeted update: validate path is reachable and save just the target
			local relativeSegments = getRelativeSegments(entry.robloxPath, targetRobloxPath)
			local targetDepth = #relativeSegments

			-- Validate the path is reachable (not inside a serialized file)
			local targetInstance = validateAndResolveTarget(game, entry.robloxPath, relativeSegments, effectiveMaxDepth)

			-- Calculate filesystem path for this specific target
			local targetFilesystemPath =
				buildTargetFilesystemPath(entry.filesystemPath, relativeSegments, targetInstance, targetDepth, effectiveMaxDepth)

			-- Calculate remaining expansion depth for this target
			local remainingDepth = effectiveMaxDepth - targetDepth

			print(`[placefs] Saving: {targetRobloxPath} -> {targetFilesystemPath}`)
			save_asset(game, targetRobloxPath, targetFilesystemPath, remainingDepth)
		end
	end

	print("[placefs] Update complete.")
end
