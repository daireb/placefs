local net = require("@lune/net")
local roblox = require("@lune/roblox")

--- Downloads a Roblox place asset as a serialised string
local function downloadPlaceAsset(placeId: number, auth_cookie: string): string
	assert(auth_cookie ~= nil, "ROBLOSECURITY cookie is required to download place assets")
	assert(typeof(auth_cookie) == "string", "ROBLOSECURITY cookie must be a string")

	local result = net.request({
		url = "https://assetdelivery.roblox.com/v1/asset/",
		headers = {
			Cookie = auth_cookie,
		},
		query = {
			id = tostring(placeId),
		},
	})

	assert(result.ok, result.statusMessage)

	return result.body
end

--- Downloads and deserializes a Roblox place
return function(placeId: number, auth_cookie: string)
	local content = downloadPlaceAsset(placeId, auth_cookie)
	local game = roblox.deserializePlace(content)
	return game
end
