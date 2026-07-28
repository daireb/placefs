local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local get_auth_cookie = require("./get_auth_cookie")
local download_place = require("./download_place")
local load_config = require("./load_config")
local resolveFilesystemPath = require("./resolve_filesystem_path")

local CONFIG_HEADER = "# placefs configuration file\n\n[settings]\n"

--- Prompts for a stable place name used by the CLI and generated filenames.
local function promptPlaceName(): string
	local input = stdio.prompt("text", "Enter a name for this place (for example: maps)")

	if input == nil or input == "" then
		print("[placefs] Error: No place name provided.")
		process.exit(1)
	end

	if input:match("^[%w][%w_-]*$") == nil then
		print("[placefs] Error: Place names may only contain letters, numbers, hyphens, and underscores.")
		process.exit(1)
	end

	return input
end

--- Prompts the user for a place ID and validates the input
local function promptPlaceId(): number
	local input = stdio.prompt("text", "Enter your Roblox place ID")

	if input == nil or input == "" then
		print("[placefs] Error: No place ID provided.")
		process.exit(1)
	end

	local placeId = tonumber(input)

	if placeId == nil or placeId ~= math.floor(placeId) or placeId <= 0 then
		print("[placefs] Error: Invalid place ID. Must be a positive integer.")
		process.exit(1)
	end

	return placeId :: number
end

--- Attempts to verify access to the place by downloading it
local function verifyPlaceAccess(placeId: number): boolean
	print("[placefs] Verifying access to place...")

	local ok, _ = pcall(function()
		local auth_cookie = get_auth_cookie()
		download_place(placeId, auth_cookie, { quiet = true })
	end)

	if ok then
		print(`[placefs] Verified access to place {placeId}`)
		return true
	else
		print(`[placefs] Warning: Could not access place {placeId}`)
		print("[placefs]   Check that the place ID is correct and you have edit permissions.")
		return false
	end
end

local function encodePlace(placeName: string, placeId: number): string
	return serde.encode("toml", {
		places = {
			[placeName] = {
				placeId = placeId,
				assets = {
					["game.Workspace.MyModel"] = "./assets/my-model.rbxm",
				},
			},
		},
	})
end

--- Creates a config or appends a place while preserving existing text.
local function writePlace(placeName: string, placeId: number, configPath: string)
	local fullPath = resolveFilesystemPath(configPath)

	if fs.isFile(fullPath) then
		local config = load_config(fullPath)
		if config.places[placeName] ~= nil then
			print(`[placefs] Error: Place '{placeName}' already exists in {configPath}.`)
			process.exit(1)
		end

		local existing = fs.readFile(fullPath):gsub("%s*$", "")
		local updated = existing .. "\n\n" .. encodePlace(placeName, placeId) .. "\n"
		local valid, parseError = pcall(function()
			serde.decode("toml", updated)
		end)
		if not valid then
			print(`[placefs] Error: Cannot safely append a place to {configPath}: {tostring(parseError)}`)
			print("[placefs] Add the [places.<name>] section manually instead.")
			process.exit(1)
		end

		fs.writeFile(fullPath, updated)
		print("")
		print(`[placefs] Added place '{placeName}' to {configPath}`)
	else
		fs.writeFile(fullPath, CONFIG_HEADER .. "\n" .. encodePlace(placeName, placeId) .. "\n")
		print("")
		print(`[placefs] Created {configPath} with place '{placeName}'`)
	end
end

local function rejectDuplicatePlace(placeName: string, configPath: string)
	local fullPath = resolveFilesystemPath(configPath)
	if fs.isFile(fullPath) and load_config(fullPath).places[placeName] ~= nil then
		print(`[placefs] Error: Place '{placeName}' already exists in {configPath}.`)
		process.exit(1)
	end
end

--- Main setup flow
--- @param configPath path for the config file (provided by --config, defaults to placefs.toml)
return function(configPath: string)
	local placeName = promptPlaceName()
	rejectDuplicatePlace(placeName, configPath)
	local placeId = promptPlaceId()
	verifyPlaceAccess(placeId)
	writePlace(placeName, placeId, configPath)
end
