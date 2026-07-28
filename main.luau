local process = require("@lune/process")

local parseArgs = require("./lib/parse_args")
local update_assets = require("./lib/update_assets")
local load_config = require("./lib/load_config")
local resolve_target = require("./lib/resolve_target")
local resolveFilesystemPath = require("./lib/resolve_filesystem_path")

local args = parseArgs({
	name = "placefs",
	version = "1.0.0",
	description = "Sync Roblox instances from a published place to your local filesystem",
	options = {
		config = {
			short = "c",
			description = "Path to config file",
			default = "placefs.toml",
			env = "PLACEFS_CONFIG",
		},
		place = { short = "p", description = "Configured place name", env = "PLACEFS_PLACE" },
	},
	flags = {
		all = { short = "a", description = "Update all mapped assets" },
		["dry-run"] = { short = "n", description = "Preview changes without writing files" },
		quiet = { short = "q", description = "Suppress output except errors" },
	},
	subcommands = {
		setup = { description = "Add a place to the config file" },
		places = { description = "List configured places" },
		project = {
			description = "Generate Rojo project files from your config",
			options = {
				output = { short = "o", description = "Output file path (derived from place name)" },
			},
		},
	},
	examples = {
		"pesde run placefs -- --all",
		"pesde run placefs -- --place maps --all",
		"pesde run placefs -- --place maps game.Workspace.Maps",
		"pesde run placefs -- --place maps assets/maps/Level1",
		"pesde run placefs -- setup",
		"pesde run placefs -- places",
		"pesde run placefs -- project --place maps",
	},
})

if args.subcommand == "setup" then
	require("./lib/setup")(args.options.config)
	return nil
end

if args.subcommand == "project" then
	require("./lib/generate_project")(args.options.config, args.options.place, args.options.output)
	return nil
end

local config_path = resolveFilesystemPath(args.options.config)
local config = load_config(config_path)

if args.subcommand == "places" then
	local names = {}
	for name in config.places do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local place = config.places[name]
		print(string.format("%s\t%d\t%d assets", name, place.placeId, #place.map))
	end
	return nil
end

-- Default command: sync assets from Roblox to filesystem
local targets = resolve_target(config, {
	place = args.options.place,
	positionals = args.positionals,
	all = args.flags.all,
})

if #targets > 1 and not args.flags.quiet then
	print(`[placefs] Syncing {#targets} places...`)
end

local failures = 0
local failedPlaces: { string } = {}

for _, target in targets do
	if not args.flags.quiet then
		print(`\n[placefs] Place: {target.placeName}`)
	end

	-- A place that cannot be downloaded must not abort the places after it
	local ok, result = pcall(update_assets, target.syncConfig, target.robloxPaths, {
		dryRun = args.flags["dry-run"],
		quiet = args.flags.quiet,
	})

	if not ok then
		failures += 1
		table.insert(failedPlaces, target.placeName)
		print(`[placefs] Place '{target.placeName}' failed: {tostring(result)}`)
	else
		local placeFailures = result :: number
		failures += placeFailures
		if placeFailures > 0 then
			table.insert(failedPlaces, target.placeName)
		end
	end
end

if #targets > 1 and #failedPlaces > 0 then
	print(`\n[placefs] {#failedPlaces} of {#targets} places had failures: {table.concat(failedPlaces, ", ")}`)
end

if failures > 0 then
	process.exit(1)
end

return nil
