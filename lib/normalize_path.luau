--[[
	Normalizes a Roblox path to use the canonical `game.Workspace.X` format.
	Converts `workspace.X` to `game.Workspace.X`.
]]
return function(path: string): string
	if path:sub(1, 10) == "workspace." then
		return "game.Workspace." .. path:sub(11)
	end
	return path
end
