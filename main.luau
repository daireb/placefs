local process = require("@lune/process")

local parseArgs = require("./lib/parse_args")
local update_assets = require("./lib/update_assets")
local load_config = require("./lib/load_config")
local resolve_target = require("./lib/resolve_target")
local resolveFilesystemPath = require("./lib/resolve_filesystem_path")
local cleanError = require("./lib/clean_error")

--- Formats a caught error, keeping the traceback when PLACEFS_DEBUG is set.
local function formatError(err: any): string
	if process.env.PLACEFS_DEBUG then
		return debug.traceback(tostring(err), 2)
	end
	return cleanError(err)
end

local function run()
	local args = parseArgs({
		name = "placefs",
		version = "1.2.0",
		description = "Sync Roblox instances from a published place or package to your local filesystem",
		options = {
			config = {
				short = "c",
				description = "Path to config file",
				default = "placefs.toml",
				env = "PLACEFS_CONFIG",
			},
			place = { short = "p", description = "Configured place or package name", env = "PLACEFS_PLACE" },
		},
		flags = {
			all = { short = "a", description = "Update all mapped assets" },
			["dry-run"] = { short = "n", description = "Preview changes without writing files" },
			quiet = { short = "q", description = "Suppress output except errors" },
			["allow-unpacked-materials"] = {
				description = "Save assets whose MaterialVariants have no texture pack",
			},
		},
		subcommands = {
			setup = { description = "Add a place to the config file" },
			places = { description = "List configured places and packages" },
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
		return
	end

	if args.subcommand == "project" then
		require("./lib/generate_project")(args.options.config, args.options.place, args.options.output)
		return
	end

	local config_path = resolveFilesystemPath(args.options.config)
	local config = load_config(config_path)

	if args.subcommand == "places" then
		local rows: { { string } } = {}
		local function addRow(name: string, source: string, count: number)
			table.insert(rows, { name, source, `{count} {if count == 1 then "asset" else "assets"}` })
		end

		for name, place in config.places do
			addRow(name, tostring(place.placeId), #place.map)
		end
		for name, package in config.packages do
			local version = if package.version ~= nil then `@{package.version}` else ""
			addRow(name, `package {package.packageId}{version}`, #package.map)
		end
		table.sort(rows, function(a, b)
			return a[1] < b[1]
		end)

		local widestName, widestSource = 0, 0
		for _, row in rows do
			widestName = math.max(widestName, #row[1])
			widestSource = math.max(widestSource, #row[2])
		end
		for _, row in rows do
			local namePadding = string.rep(" ", widestName - #row[1])
			local sourcePadding = string.rep(" ", widestSource - #row[2])
			print(`{row[1]}{namePadding}  {row[2]}{sourcePadding}  {row[3]}`)
		end
		return
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
			local kind = if target.syncConfig.packageId ~= nil then "Package" else "Place"
			print(`\n[placefs] {kind}: {target.placeName}`)
		end

		-- A place or package that cannot be downloaded must not abort the ones after it
		local ok, result = pcall(update_assets, target.syncConfig, target.robloxPaths, {
			dryRun = args.flags["dry-run"],
			quiet = args.flags.quiet,
			allowUnpackedMaterials = args.flags["allow-unpacked-materials"],
		})

		if not ok then
			failures += 1
			table.insert(failedPlaces, target.placeName)
			print(`[placefs] Place '{target.placeName}' failed: {cleanError(result)}`)
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
end

local ok, err = xpcall(run, formatError)

if not ok then
	print(`[placefs] Error: {err}`)
	process.exit(1)
end

return nil
