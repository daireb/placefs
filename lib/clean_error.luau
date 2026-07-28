--[[
	Strips the "<script>:<line>: " prefix Lune prepends to runtime errors,
	so user-facing output shows only the message itself.
]]
return function(err: any): string
	return (tostring(err):gsub("^[^\n]-:%d+: ", ""))
end
