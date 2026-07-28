local fs = require("@lune/fs")
local serde = require("@lune/serde")

local loadConfig = require("../lib/load_config")

return function()
	local path = `/tmp/placefs-load-config-{os.clock()}.toml`

	local ok, message = pcall(function()
		fs.writeFile(
			path,
			serde.encode("toml", {
				settings = { maxExpansionDepth = 4 },
				places = {
					maps = {
						placeId = 123,
						maxExpansionDepth = 3,
						assets = {
							{
								robloxPath = "workspace.Map",
								filesystemPath = "./assets/map.rbxm",
								maxExpansionDepth = 0,
							},
							{
								robloxPath = "game.Workspace.Story",
								filesystemPath = "./assets/story",
							},
						},
					},
				},
			})
		)

		local config = loadConfig(path)
		assert(config.places.maps.placeId == 123)
		assert(config.places.maps.map[1].robloxPath == "game.Workspace.Map")
		assert(config.places.maps.map[1].maxExpansionDepth == 0)
		assert(config.places.maps.map[2].maxExpansionDepth == 3)

		fs.writeFile(
			path,
			'[places.maps]\nplaceId = 123\n\n[[places.maps.assets]]\nrobloxPath = "game.Workspace.Map"\nfilesystemPath = "./"\n'
		)
		local rootLoaded, rootError = pcall(function()
			loadConfig(path)
		end)
		assert(not rootLoaded)
		assert(tostring(rootError):find("cannot target the filesystem root", 1, true))

		fs.writeFile(
			path,
			'[settings]\nplaceId = 123\n\n[[assets]]\nrobloxPath = "game.Workspace.Map"\nfilesystemPath = "./assets/map.rbxm"\n'
		)
		local loaded, loadError = pcall(function()
			loadConfig(path)
		end)
		assert(not loaded)
		assert(tostring(loadError):find("placefs v0 config", 1, true))
	end)

	if fs.isFile(path) then
		fs.removeFile(path)
	end

	assert(ok, message)
end
