local roblox = require("@lune/roblox")

local Types = require("./Types")

local cleanError = require("./clean_error")
local download_package = require("./download_package")
local download_place = require("./download_place")
local get_auth_cookie = require("./get_auth_cookie")
local resolve_root = require("./resolve_root")
local save_asset = require("./save_asset")

local DEFAULT_MAX_EXPANSION_DEPTH = 2

type UpdateResult = {
	path: string,
	success: boolean,
	error: string?,
}

--- Logs a message unless quiet mode is enabled.
local function log(message: string, options: Types.Options?)
	if not (options and options.quiet) then
		print(message)
	end
end

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
--- @param root The downloaded place's DataModel or package container
--- @param ancestorPath The Roblox path of the mapping entry (e.g., "game.Workspace.Parts")
--- @param relativeSegments The path segments from ancestor to target (e.g., {"Gun", "Handle"})
--- @param maxDepth The effective max expansion depth for this entry
--- @return The resolved target instance if reachable
local function validateAndResolveTarget(
	root: roblox.Instance,
	ancestorPath: string,
	relativeSegments: { string },
	maxDepth: number
): roblox.Instance
	local rootInstance, remainingPath = resolve_root(root, ancestorPath)
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

	-- Add each segment as a directory
	for _, segment in relativeSegments do
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

--- Prints a summary of update results and returns the error count.
local function printSummary(results: { UpdateResult }, options: Types.Options?): number
	local successCount, errorCount = 0, 0
	local errors: { UpdateResult } = {}

	for _, result in results do
		if result.success then
			successCount += 1
		else
			errorCount += 1
			table.insert(errors, result)
		end
	end

	local isDryRun = options and options.dryRun
	local successWord = if isDryRun then "would succeed" else "succeeded"
	local failWord = if isDryRun then "would fail" else "failed"

	log(string.format("\n[placefs] Summary: %d %s, %d %s", successCount, successWord, errorCount, failWord), options)

	if #errors > 0 then
		-- Always print errors, even in quiet mode
		print("[placefs] Errors:")
		for _, result in errors do
			print(string.format("  - %s: %s", result.path, result.error or "Unknown error"))
		end
	end

	return errorCount
end

--- Updates assets and returns the number of failures (0 = all successful).
return function(syncConfig: Types.SyncConfig, instancesToUpdate: { string }, options: Types.Options?): number
	local entryLookup = buildEntryLookup(syncConfig.map)
	local isDryRun = options and options.dryRun

	if isDryRun then
		log("[placefs] DRY RUN - no files will be written", options)
	end

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

	local auth_cookie = get_auth_cookie()
	local root: roblox.Instance = if syncConfig.packageId ~= nil
		then download_package(syncConfig.packageId, syncConfig.version, auth_cookie, options)
		else download_place(syncConfig.placeId :: number, auth_cookie, options)

	-- Track results for summary
	local results: { UpdateResult } = {}

	-- Save each requested instance
	local actionWord = if isDryRun then "Checking" else "Updating"
	log(string.format("[placefs] %s %d instances...", actionWord, #instancesToUpdate), options)

	for _, targetRobloxPath in instancesToUpdate do
		local entry = findAncestorEntry(entryLookup, targetRobloxPath)
		if entry == nil then
			table.insert(results, {
				path = targetRobloxPath,
				success = false,
				error = "No matching mapping found",
			})
			continue
		end

		local effectiveMaxDepth = getEffectiveMaxDepth(entry)

		local saveWord = if isDryRun then "Would save" else "Saving"

		local ok, err = pcall(function()
			if targetRobloxPath == entry.robloxPath then
				-- Exact match: save the whole mapping
				log(`[placefs] {saveWord}: {entry.robloxPath} -> {entry.filesystemPath}`, options)
				save_asset(root, entry.robloxPath, entry.filesystemPath, effectiveMaxDepth, options)
			else
				-- Targeted update: validate path is reachable and save just the target
				local relativeSegments = getRelativeSegments(entry.robloxPath, targetRobloxPath)
				local targetDepth = #relativeSegments

				-- Validate the path is reachable (not inside a serialized file)
				local targetInstance =
					validateAndResolveTarget(root, entry.robloxPath, relativeSegments, effectiveMaxDepth)

				-- Calculate filesystem path for this specific target
				local targetFilesystemPath = buildTargetFilesystemPath(
					entry.filesystemPath,
					relativeSegments,
					targetInstance,
					targetDepth,
					effectiveMaxDepth
				)

				-- Calculate remaining expansion depth for this target
				local remainingDepth = effectiveMaxDepth - targetDepth

				log(`[placefs] {saveWord}: {targetRobloxPath} -> {targetFilesystemPath}`, options)
				save_asset(root, targetRobloxPath, targetFilesystemPath, remainingDepth, options)
			end
		end)

		if ok then
			table.insert(results, { path = targetRobloxPath, success = true })
		else
			table.insert(results, { path = targetRobloxPath, success = false, error = cleanError(err) })
		end
	end

	return printSummary(results, options)
end
