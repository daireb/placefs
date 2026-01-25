local process = require("@lune/process")

local update_assets = require("./lib/update_assets")
local load_sync_config = require("./lib/load_sync_config")

local config_path = process.cwd .. "asset-map.json"

local config = load_sync_config(config_path)

local to_update = {}
for _, arg in process.args do
	table.insert(to_update, arg)
end

if #to_update == 0 then
	error("No instances specified to update. Provide Roblox instance paths as command-line arguments.")
end

update_assets(config, to_update)

return nil
