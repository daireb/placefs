local Types = require("./Types")

local download_place = require("./download_place")
local get_auth_cookie = require("./get_auth_cookie")
local save_asset = require("./save_asset")

--- Builds a lookup table of known Roblox instance paths to filesystem paths.
local function buildKnownInstances(asset_map: Types.AssetMap): { [string]: string }
	local knownInstances = {}

	for _, entry in asset_map do
		knownInstances[entry.robloxPath] = entry.filesystemPath
	end

	return knownInstances
end

--- Finds the nearest known ancestor for a given Roblox path.
local function getKnownAncestor(knownInstances: { [string]: any }, robloxPath: string): string?
	local pathSegments = robloxPath:split(".")

	while #pathSegments > 0 do
		local currentPath = table.concat(pathSegments, ".")
		if knownInstances[currentPath] ~= nil then
			return currentPath
		end

		table.remove(pathSegments)
	end

	return nil
end

return function(syncConfig: Types.SyncConfig, instancesToUpdate: { string })
	local knownInstances = buildKnownInstances(syncConfig.map)

	-- Check for any duplicates in assetMap
	for _, entry in syncConfig.map do
		local ancestor = getKnownAncestor(knownInstances, entry.robloxPath)
		if ancestor and ancestor ~= entry.robloxPath then
			error(
				`Asset map contains overlapping entries: '{entry.robloxPath}' overlaps with known ancestor '{ancestor}'`
			)
		end
	end

	-- Check for duplicates in instancesToUpdate
	local instancesToUpdateLookup = {}
	for _, robloxPath in instancesToUpdate do
		if instancesToUpdateLookup[robloxPath] then
			error(`Duplicate instance path in instancesToUpdate: '{robloxPath}'`)
		end

		local ancestor = getKnownAncestor(instancesToUpdateLookup, robloxPath)
		if ancestor then
			error(`Instance path '{robloxPath}' overlaps with known ancestor '{ancestor}'`)
		end

		instancesToUpdateLookup[robloxPath] = true
	end

	-- Download place from Roblox
	local auth_cookie = get_auth_cookie()
	local game = download_place(syncConfig.placeId, auth_cookie)

	-- Save each requested instance
	print(string.format("[placefs] Updating %i instances...", #instancesToUpdate))

	for _, robloxPath in instancesToUpdate do
		local ancestorRobloxPath = getKnownAncestor(knownInstances, robloxPath)
		if ancestorRobloxPath == nil then
			print(`No known ancestor found for instance path: '{robloxPath}', skipping.`)
			continue
		end

		local filesystemPath = knownInstances[ancestorRobloxPath]
		save_asset(game, ancestorRobloxPath, filesystemPath)
	end

	print("[placefs] Update complete.")
end
