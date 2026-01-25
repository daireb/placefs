local process = require("@lune/process")

local update_assets = require("./lib/update_assets")
local load_sync_config = require("./lib/load_sync_config")

local config_path = process.cwd .. "placefs.toml"

local config = load_sync_config(config_path)

local to_update = {}

-- Check for --all flag
if #process.args == 1 and (process.args[1] == "--all" or process.args[1] == "all") then
	-- Gather all robloxPaths from config
	for _, entry in config.map do
		table.insert(to_update, entry.robloxPath)
	end
elseif #process.args == 0 then
	error("No instances specified. Use '--all' to update all assets, or provide Roblox instance paths.")
else
	-- Use provided paths
	for _, arg in process.args do
		table.insert(to_update, arg)
	end
end

update_assets(config, to_update)

return nil
