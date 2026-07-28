--[[
	Represents a mapping between a Roblox instance path and its filesystem location.
]]
export type AssetMapEntry = {
	--- The corresponding path within Roblox.
	robloxPath: string,

	--- The corresponding path on the local filesystem, relative to the project root.
	filesystemPath: string,

	--- How deep to parse nested folders? Defaults to 2.
	maxExpansionDepth: number?,
}

export type AssetMap = { AssetMapEntry }

--[[
	Configuration for syncing a Roblox place's assets to the filesystem.
]]
export type SyncConfig = {
	--- The place ID on Roblox.
	placeId: number,
	map: AssetMap,
}

--- Shared defaults from the top-level [settings] table.
export type Settings = {
	maxExpansionDepth: number?,
}

--- The complete placefs configuration.
export type Config = {
	settings: Settings,
	places: { [string]: SyncConfig },
}

--- A single place and its resolved Roblox paths for one sync operation.
export type ResolvedTarget = {
	placeName: string,
	syncConfig: SyncConfig,
	robloxPaths: { string },
}

--[[
	Runtime options passed through the CLI.
]]
export type Options = {
	--- Preview changes without writing files.
	dryRun: boolean?,
	--- Suppress output except errors.
	quiet: boolean?,
}

return nil
