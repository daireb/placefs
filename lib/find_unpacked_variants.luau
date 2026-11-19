local roblox = require("@lune/roblox")

--- Whether a content property is set. `name` is the legacy property (`TexturePack`); current files store it as
--- `<name>Content`. Falls back to the instance's own XML properties, since Lune lacks a member for some of these
--- and reads the legacy one as empty on a current file.
local function hasContent(instance: roblox.Instance, properties: string, name: string): boolean
	local ok, value = pcall(function()
		return (instance :: any)[name .. "Content"]
	end)
	if ok and typeof(value) == "Content" then
		return value.SourceType ~= (roblox.Enum :: any).ContentSourceType.None
	end

	local tag, text = string.match(properties, `name="{name}%w*">%s*<(%w+)>%s*([^<]*)`)
	return (tag == "uri" or tag == "url") and text ~= ""
end

--- The MaterialVariants at or under `instance` that have a colour map but no compiled texture pack, each as
--- `Name (BaseMaterial)` since a name can repeat across base materials, sorted.
--- Studio compiles the pack some time after a variant changes and live servers draw from it alone, so a place
--- published in between saves variants that show as the plain base material in game.
return function(instance: roblox.Instance): { string }
	local candidates = instance:GetDescendants()
	table.insert(candidates, instance)

	local unpacked: { string } = {}
	for _, candidate in candidates do
		if candidate.ClassName ~= "MaterialVariant" then
			continue
		end

		-- Cut before the children: a TerrainDetail child carries properties of the same names
		local xml = roblox.serializeModel({ candidate }, true)
		local properties = string.match(xml, "^(.-)</Properties>") or xml

		if hasContent(candidate, properties, "ColorMap") and not hasContent(candidate, properties, "TexturePack") then
			table.insert(unpacked, `{candidate.Name} ({(candidate :: any).BaseMaterial.Name})`)
		end
	end

	table.sort(unpacked)
	return unpacked
end
