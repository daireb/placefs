local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local findUnpackedVariants = require("../lib/find_unpacked_variants")
local saveAsset = require("../lib/save_asset")

local COLOR = '<Content name="ColorMapContent"><uri>rbxassetid://1</uri></Content>'
local LEGACY_COLOR = '<Content name="ColorMap"><url>rbxassetid://1</url></Content>'
--- A child every terrain-capable variant has, with a pack of its own that must not count as the variant's.
local PACKED_DETAIL = '<Item class="TerrainDetail" referent="1"><Properties><string name="Name">TerrainDetail</string>'
	.. COLOR
	.. '<Content name="TexturePackContent"><uri>rbxassetid://3</uri></Content></Properties></Item>'

--- Deserializes a MaterialVariant from the XML form, the only way to build each stored property shape.
local function variant(name: string, properties: string, children: string?): roblox.Instance
	local xml = `<roblox version="4"><Item class="MaterialVariant" referent="0"><Properties>`
		.. `<string name="Name">{name}</string>{properties}</Properties>{children or ""}</Item></roblox>`
	return roblox.deserializeModel(xml)[1]
end

local function expectNames(instance: roblox.Instance, expected: { string }, case: string)
	local names = table.concat(findUnpackedVariants(instance), ", ")
	local wanted = table.concat(expected, ", ")
	assert(names == wanted, `{case}: expected [{wanted}], got [{names}]`)
end

return function()
	-- Current form (`TexturePackContent`)
	expectNames(
		variant("Set", COLOR .. '<Content name="TexturePackContent"><uri>rbxassetid://2</uri></Content>'),
		{},
		"current, pack set"
	)
	expectNames(
		variant("Empty", COLOR .. '<Content name="TexturePackContent"><null></null></Content>'),
		{ "Empty (Plastic)" },
		"current, pack empty"
	)
	expectNames(variant("Bare", COLOR, PACKED_DETAIL), { "Bare (Plastic)" }, "no pack beside a packed TerrainDetail")
	expectNames(
		variant("EmptyUri", '<Content name="ColorMapContent"><uri></uri></Content>'),
		{},
		"an empty uri is no colour map"
	)

	-- Legacy form (`TexturePack`)
	expectNames(
		variant("LegacySet", LEGACY_COLOR .. '<Content name="TexturePack"><url>rbxassetid://2</url></Content>'),
		{},
		"legacy, pack set"
	)
	expectNames(
		variant("LegacyEmpty", LEGACY_COLOR .. '<Content name="TexturePack"><null></null></Content>'),
		{ "LegacyEmpty (Plastic)" },
		"legacy, pack empty"
	)
	expectNames(variant("LegacyAbsent", LEGACY_COLOR), { "LegacyAbsent (Plastic)" }, "legacy, pack absent")

	-- Both spellings in one file: a pack under either counts
	expectNames(
		variant(
			"Both",
			COLOR
				.. '<Content name="TexturePack"><null></null></Content>'
				.. '<Content name="TexturePackContent"><uri>rbxassetid://2</uri></Content>'
		),
		{},
		"empty legacy pack beside a set current one"
	)

	-- A variant with no colour map has nothing to compile
	expectNames(variant("Blank", ""), {}, "no colour map")

	-- Descendants are found and reported in name order
	local game = roblox.Instance.new("DataModel")
	local materials = roblox.Instance.new("Folder")
	materials.Name = "Materials"
	materials.Parent = game:GetService("MaterialService")
	for _, name in { "Zinc", "Brick" } do
		variant(name, COLOR .. '<Content name="TexturePackContent"><null></null></Content>').Parent = materials
	end
	variant("Packed", COLOR .. '<Content name="TexturePackContent"><uri>rbxassetid://2</uri></Content>').Parent =
		materials
	expectNames(materials, { "Brick (Plastic)", "Zinc (Plastic)" }, "descendants")

	-- Saving refuses and leaves the file on disk as it was, as a file and as an expanded folder
	local file = "/tmp/placefs-unpacked-variants.rbxm"
	local folder = "/tmp/placefs-unpacked-variants"
	local ok, message = pcall(function()
		fs.writeFile(file, "previous")
		fs.writeDir(folder)
		fs.writeFile(folder .. "/keep.rbxm", "previous")

		for _, target in { file, folder } do
			local saved, err = pcall(saveAsset, game, "game.MaterialService.Materials", target, 2, { quiet = true })
			assert(not saved, `save to {target} should be refused`)
			assert(
				tostring(err):find("Brick (Plastic), Zinc (Plastic)", 1, true),
				`error should name the variants, got '{tostring(err)}'`
			)
			assert(tostring(err):find("mid-compile", 1, true), `error should say why, got '{tostring(err)}'`)
		end
		assert(fs.readFile(file) == "previous", "a refused save must not overwrite the file")
		assert(fs.readFile(folder .. "/keep.rbxm") == "previous", "a refused save must not clear the folder")

		-- The flag saves anyway
		saveAsset(game, "game.MaterialService.Materials", file, 2, { quiet = true, allowUnpackedMaterials = true })
		assert(fs.readFile(file) ~= "previous", "allowUnpackedMaterials should write the file")
	end)

	if fs.isFile(file) then
		fs.removeFile(file)
	end
	if fs.isDir(folder) then
		fs.removeDir(folder)
	end
	assert(ok, tostring(message))
end
