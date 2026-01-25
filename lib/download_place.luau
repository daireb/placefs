local net = require("@lune/net")
local roblox = require("@lune/roblox")

--- Formats bytes into a human-readable string
local function formatBytes(bytes: number): string
	if bytes < 1024 then
		return string.format("%d B", bytes)
	elseif bytes < 1024 * 1024 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.1f MB", bytes / (1024 * 1024))
	end
end

--- Downloads a Roblox place asset as a serialised string
local function downloadPlaceAsset(placeId: number, auth_cookie: string): string
	assert(auth_cookie ~= nil, "ROBLOSECURITY cookie is required to download place assets")
	assert(typeof(auth_cookie) == "string", "ROBLOSECURITY cookie must be a string")

	print(`[placefs] Downloading place {placeId}...`)

	local startTime = os.clock()

	local result = net.request({
		url = "https://assetdelivery.roblox.com/v1/asset/",
		headers = {
			Cookie = auth_cookie,
		},
		query = {
			id = tostring(placeId),
		},
	})

	assert(result.ok, `Download failed: {result.statusMessage} (status {result.statusCode})`)

	local elapsed = os.clock() - startTime
	local size = #result.body

	print(string.format("[placefs] Downloaded %s in %.1fs", formatBytes(size), elapsed))

	return result.body
end

--- Downloads and deserializes a Roblox place
return function(placeId: number, auth_cookie: string)
	local content = downloadPlaceAsset(placeId, auth_cookie)

	print("[placefs] Deserializing place...")
	local startTime = os.clock()

	local game = roblox.deserializePlace(content)

	local elapsed = os.clock() - startTime
	print(string.format("[placefs] Deserialized in %.1fs", elapsed))

	return game
end
