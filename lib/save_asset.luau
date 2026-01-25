local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local function parseRobloxPath(parent: roblox.Instance, path: string): roblox.Instance?
	local segments = path:split(".")
	local currentInstance: roblox.Instance? = parent

	for _, segment in segments do
		if currentInstance == nil then
			return nil
		end

		currentInstance = currentInstance:FindFirstChild(segment)
	end

	return currentInstance
end

--- Saves a Roblox instance to the filesystem at the specified path.
return function(game: roblox.DataModel, robloxPath: string, filesystemPath: string)
	-- Determine root instance of robloxPath
	local root_instance: roblox.Instance?
	if robloxPath:sub(1, 5) == "game." then
		root_instance = game
		robloxPath = robloxPath:sub(6)
	elseif robloxPath:sub(1, 10) == "workspace." then
		root_instance = game:FindFirstChild("Workspace")
		robloxPath = robloxPath:sub(11)
	end

	if root_instance == nil then
		error(`Invalid Roblox path: '{robloxPath}'. Failed to determine path's root instance.`)
	end

	-- Locate instance in data model
	local instance = parseRobloxPath(root_instance, robloxPath)
	if instance == nil then
		error(`Instance not found at Roblox path: '{robloxPath}'`)
	end

	-- Validate filesystem path
	if filesystemPath:sub(-5) ~= ".rbxm" and filesystemPath:sub(-6) ~= ".rbxmx" then
		error(`Filesystem path must end with '.rbxm' or '.rbxmx': '{filesystemPath}'`)
	end

	-- Serialize instance
	local use_xml = filesystemPath:sub(-6) == ".rbxmx"
	local serializedData = roblox.serializeModel({ instance }, use_xml)

	-- Write to filesystem
	fs.writeFile(filesystemPath, serializedData)
end
