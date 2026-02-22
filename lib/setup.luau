local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local get_auth_cookie = require("./get_auth_cookie")
local download_place = require("./download_place")

local CONFIG_HEADER = "# placefs configuration file\n\n"

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

--- Creates the config file with the given place ID
local function writeConfig(placeId: number, configPath: string)
	local fullPath = process.cwd .. configPath

	-- Check if config already exists
	if fs.isFile(fullPath) then
		print(`[placefs] Error: {configPath} already exists. Delete it first or edit it manually.`)
		process.exit(1)
	end

	-- Encode sections separately to control ordering
	local settingsToml = serde.encode("toml", {
		settings = { placeId = placeId },
	})

	local assetsToml = serde.encode("toml", {
		assets = {
			{
				robloxPath = "game.Workspace.MyModel",
				filesystemPath = "./assets/my-model.rbxm",
			},
		},
	})

	-- Serialize and write with correct section order
	local content = CONFIG_HEADER .. settingsToml .. "\n" .. assetsToml
	fs.writeFile(fullPath, content)

	print("")
	print(`[placefs] Created {configPath}`)
end

--- Main setup flow
--- @param configPath path for the config file (provided by --config, defaults to placefs.toml)
return function(configPath: string)
	local placeId = promptPlaceId()
	verifyPlaceAccess(placeId)
	writeConfig(placeId, configPath)
end
