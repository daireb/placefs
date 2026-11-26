local roblox = require("@lune/roblox")

local Types = require("./Types")

local download_asset = require("./download_asset")

--- Downloads and deserializes a Roblox place
return function(placeId: number, auth_cookie: string, options: Types.Options?): roblox.DataModel
	local content = download_asset(placeId, nil, `place {placeId}`, auth_cookie, options)

	if not (options and options.quiet) then
		print("[placefs] Deserializing place...")
	end
	local startTime = os.clock()

	local game = roblox.deserializePlace(content)

	if not (options and options.quiet) then
		print(string.format("[placefs] Deserialized in %.1fs", os.clock() - startTime))
	end

	return game
end
