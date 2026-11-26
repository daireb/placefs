local net = require("@lune/net")

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

--- Downloads an asset's serialized content from asset delivery; the latest version when `version` is nil.
--- `label` names the asset in the log, such as "place 123".
return function(assetId: number, version: number?, label: string, auth_cookie: string, options: Types.Options?): string
	assert(auth_cookie ~= nil, "ROBLOSECURITY cookie is required to download assets")
	assert(typeof(auth_cookie) == "string", "ROBLOSECURITY cookie must be a string")

	log(`[placefs] Downloading {label}...`, options)

	local startTime = os.clock()

	local query: net.HttpQueryMap = { id = tostring(assetId) }
	if version ~= nil then
		query.version = tostring(version)
	end

	local result = net.request({
		url = "https://assetdelivery.roblox.com/v1/asset/",
		headers = {
			Cookie = auth_cookie,
		},
		query = query,
	})

	assert(result.ok, `Download failed: {result.statusMessage} (status {result.statusCode})`)

	local elapsed = os.clock() - startTime
	log(string.format("[placefs] Downloaded %s in %.1fs", formatBytes(#result.body), elapsed), options)

	return result.body
end
