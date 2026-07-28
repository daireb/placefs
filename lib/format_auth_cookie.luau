local COOKIE_PREFIX = ".ROBLOSECURITY="

--[[
	Normalizes a cookie value into a `Cookie` header value.
	Accepts either a bare token or an already-prefixed cookie string.
]]
return function(value: string): string
	local trimmed = value:match("^%s*(.-)%s*$") or value

	if trimmed == "" then
		error("ROBLOSECURITY cookie is empty")
	end

	if trimmed:sub(1, #COOKIE_PREFIX) == COOKIE_PREFIX then
		return trimmed
	end

	return COOKIE_PREFIX .. trimmed
end
