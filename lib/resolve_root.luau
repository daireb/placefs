local roblox = require("@lune/roblox")

--- Returns the instance a Roblox path is walked from and the rest of the path. A place's
--- DataModel takes `game.` paths; a package's container takes paths that start at the package.
return function(root: roblox.Instance, robloxPath: string): (roblox.Instance, string)
	if root.ClassName ~= "DataModel" then
		return root, robloxPath
	end

	if robloxPath:sub(1, 5) ~= "game." then
		error(`Invalid Roblox path: '{robloxPath}'. Path must start with 'game.'`)
	end

	return root, robloxPath:sub(6)
end
