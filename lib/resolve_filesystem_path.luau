local process = require("@lune/process")

--- Resolves a CLI filesystem path relative to the current working directory.
return function(path: string): string
	local isAbsolute = path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil
	if isAbsolute then
		return path
	end
	return process.cwd .. path
end
