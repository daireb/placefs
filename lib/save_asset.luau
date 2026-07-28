local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local Types = require("./Types")

local DEFAULT_MAX_EXPANSION_DEPTH = 2

--- Parses a dot-separated path starting from a parent instance.
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

--- Resolves an instance from a full Roblox path (e.g., "game.Workspace.Parts").
--- Expects paths to be normalized to "game." prefix format.
local function resolveInstance(game: roblox.DataModel, robloxPath: string): roblox.Instance
	if robloxPath:sub(1, 5) ~= "game." then
		error(`Invalid Roblox path: '{robloxPath}'. Path must start with 'game.'`)
	end

	local instance = parseRobloxPath(game, robloxPath:sub(6))
	if instance == nil then
		error(`Instance not found at Roblox path: '{robloxPath}'`)
	end

	return instance
end

--- Checks if a filesystem path has a model file extension.
local function hasModelExtension(path: string): boolean
	return path:sub(-5) == ".rbxm" or path:sub(-6) == ".rbxmx"
end

--- Validates child names before using them as filesystem path segments.
local function validateChildNames(instance: roblox.Instance, options: Types.Options?)
	local children = instance:GetChildren()
	local seenNames: { [string]: boolean } = {}
	local duplicates: { string } = {}

	for _, child in children do
		local name = child.Name
		local lowerName = name:lower()
		if name:find("/", 1, true) or name:find("\\", 1, true) then
			error(`Instance name '{name}' contains a path separator and cannot be saved as a filesystem segment.`)
		end
		if lowerName:sub(-5) == ".rbxm" or lowerName:sub(-6) == ".rbxmx" then
			error(
				`Instance name '{name}' ends in a Roblox model extension and cannot round-trip through the filesystem.`
			)
		end
		if name:find(".", 1, true) and not (options and options.quiet) then
			print(
				`[placefs] Warning: Instance name '{name}' contains '.' and cannot be targeted unambiguously by Roblox path.`
			)
		end

		if seenNames[child.Name] then
			if not table.find(duplicates, child.Name) then
				table.insert(duplicates, child.Name)
			end
		else
			seenNames[child.Name] = true
		end
	end

	if #duplicates > 0 then
		local duplicateList = table.concat(duplicates, ", ")
		error(
			`Folder '{instance.Name}' contains children with duplicate names: {duplicateList}. Rename them to avoid conflicts.`
		)
	end
end

--- Validates every directory that will be expanded before any files are changed.
local function validateExpandedTree(
	instance: roblox.Instance,
	currentDepth: number,
	maxDepth: number,
	options: Types.Options?
)
	if instance.ClassName ~= "Folder" or currentDepth >= maxDepth then
		return
	end

	validateChildNames(instance, options)
	for _, child in instance:GetChildren() do
		validateExpandedTree(child, currentDepth + 1, maxDepth, options)
	end
end

--- Serializes an instance to a file.
local function serializeToFile(instance: roblox.Instance, filePath: string, options: Types.Options?)
	if options and options.dryRun then
		return
	end
	local use_xml = filePath:sub(-6) == ".rbxmx"
	local serializedData = roblox.serializeModel({ instance }, use_xml)
	fs.writeFile(filePath, serializedData)
end

--- Recursively saves a folder's contents as a directory structure.
--- @param instance The Roblox instance to save
--- @param basePath The filesystem path (without extension for folders)
--- @param currentDepth Current recursion depth (starts at 0 for the mapped root)
--- @param maxDepth Maximum expansion depth
--- @param options Runtime options
local function saveRecursive(
	instance: roblox.Instance,
	basePath: string,
	currentDepth: number,
	maxDepth: number,
	options: Types.Options?
)
	local isFolder = instance.ClassName == "Folder"
	local shouldExpand = isFolder and currentDepth < maxDepth
	local isDryRun = options and options.dryRun

	if shouldExpand then
		if not isDryRun then
			-- Clear and recreate directory to remove stale files
			if fs.isDir(basePath) then
				fs.removeDir(basePath)
			end
			fs.writeDir(basePath)
		end

		-- Recursively save children
		for _, child in instance:GetChildren() do
			local childPath = basePath .. "/" .. child.Name
			saveRecursive(child, childPath, currentDepth + 1, maxDepth, options)
		end
	else
		-- Serialize as a single .rbxm file
		local filePath = basePath .. ".rbxm"

		if not isDryRun then
			-- Ensure parent directory exists
			local parentDir = filePath:match("(.+)/[^/]+$")
			if parentDir and not fs.isDir(parentDir) then
				fs.writeDir(parentDir)
			end
		end

		serializeToFile(instance, filePath, options)
	end
end

--- Saves a Roblox instance to the filesystem at the specified path.
--- @param game The Roblox DataModel
--- @param robloxPath The path to the instance in Roblox (e.g., "game.Workspace.Parts")
--- @param filesystemPath The destination path on the filesystem
--- @param maxExpansionDepth How deep to expand folders (nil for default, 0 for no expansion)
--- @param options Runtime options
return function(
	game: roblox.DataModel,
	robloxPath: string,
	filesystemPath: string,
	maxExpansionDepth: number?,
	options: Types.Options?
)
	local instance = resolveInstance(game, robloxPath)
	local effectiveMaxDepth = maxExpansionDepth or DEFAULT_MAX_EXPANSION_DEPTH
	local isDryRun = options and options.dryRun

	if hasModelExtension(filesystemPath) then
		-- Explicit file extension: serialize as single file regardless of type
		if not isDryRun then
			-- Ensure parent directory exists
			local parentDir = filesystemPath:match("(.+)/[^/]+$")
			if parentDir and not fs.isDir(parentDir) then
				fs.writeDir(parentDir)
			end
		end

		serializeToFile(instance, filesystemPath, options)
	else
		-- No extension: must be a Folder to expand
		if instance.ClassName ~= "Folder" then
			error(
				`Cannot save non-Folder instance '{instance.Name}' (ClassName: {instance.ClassName}) to path without .rbxm or .rbxmx extension. `
					.. `Either use a file extension or ensure the instance is a Folder.`
			)
		end

		validateExpandedTree(instance, 0, effectiveMaxDepth, options)
		saveRecursive(instance, filesystemPath, 0, effectiveMaxDepth, options)
	end
end
