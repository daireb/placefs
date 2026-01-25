local net = require("@lune/net")
local roblox = require("@lune/roblox")

local Types = require("./Types")

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

--- Logs a message unless quiet mode is enabled.
local function log(message: string, options: Types.Options?)
	if not (options and options.quiet) then
		print(message)
	end
end

--- Downloads a Roblox place asset as a serialised string
local function downloadPlaceAsset(placeId: number, auth_cookie: string, options: Types.Options?): string
	assert(auth_cookie ~= nil, "ROBLOSECURITY cookie is required to download place assets")
	assert(typeof(auth_cookie) == "string", "ROBLOSECURITY cookie must be a string")

	log(`[placefs] Downloading place {placeId}...`, options)

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

	log(string.format("[placefs] Downloaded %s in %.1fs", formatBytes(size), elapsed), options)

	return result.body
end

--- Downloads and deserializes a Roblox place
return function(placeId: number, auth_cookie: string, options: Types.Options?)
	local content = downloadPlaceAsset(placeId, auth_cookie, options)

	log("[placefs] Deserializing place...", options)
	local startTime = os.clock()

	local game = roblox.deserializePlace(content)

	local elapsed = os.clock() - startTime
	log(string.format("[placefs] Deserialized in %.1fs", elapsed), options)

	return game
end
