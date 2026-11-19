local roblox = require("@lune/roblox")

--- Whether `propertiesXml` (an instance's own serialized properties) holds a non-empty value for exactly `property`.
local function xmlContentIsSet(propertiesXml: string, property: string): boolean
	local tag, text = string.match(propertiesXml, `name="{property}">%s*<(%w+)>%s*([^<]*)`)
	return (tag == "uri" or tag == "url") and text ~= ""
end

--- Whether a content property is set under either of its spellings: the legacy `name` (`TexturePack`) or the
--- current `<name>Content`. A file can carry both with only one filled. Reads the XML form as well as the member,
--- since Lune lacks a member for some of these and reads the legacy one as empty on a current file.
local function hasContent(instance: roblox.Instance, propertiesXml: string, name: string): boolean
	local ok, value = pcall(function()
		return (instance :: any)[name .. "Content"]
	end)
	if ok and typeof(value) == "Content" then
		local sourceType = value.SourceType.Name
		if sourceType == "Object" or (sourceType == "Uri" and value.Uri ~= "") then
			return true
		end
	end

	return xmlContentIsSet(propertiesXml, name .. "Content") or xmlContentIsSet(propertiesXml, name)
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
		local propertiesXml = string.match(xml, "^(.-)</Properties>") or xml

		if
			hasContent(candidate, propertiesXml, "ColorMap")
			and not hasContent(candidate, propertiesXml, "TexturePack")
		then
			table.insert(unpacked, `{candidate.Name} ({(candidate :: any).BaseMaterial.Name})`)
		end
	end

	table.sort(unpacked)
	return unpacked
end
