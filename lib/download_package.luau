local roblox = require("@lune/roblox")

local Types = require("./Types")

local download_asset = require("./download_asset")

--- Downloads a package and returns a Folder holding its root instance, so mapping
--- paths resolve from the package's own name the way place paths resolve from `game`.
return function(packageId: number, version: number?, auth_cookie: string, options: Types.Options?): roblox.Instance
	local label = if version ~= nil then `package {packageId} version {version}` else `package {packageId}`
	local content = download_asset(packageId, version, label, auth_cookie, options)

	local container = roblox.Instance.new("Folder")
	for _, root in roblox.deserializeModel(content) do
		root.Parent = container
	end

	return container
end
