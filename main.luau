local process = require("@lune/process")

local parseArgs = require("./lib/parse_args")
local update_assets = require("./lib/update_assets")
local load_sync_config = require("./lib/load_sync_config")
local normalizeRobloxPath = require("./lib/normalize_path")

local args = parseArgs({
	name = "placefs",
	version = "0.6.0",
	description = "Sync Roblox instances from a published place to your local filesystem",
	options = {
		config = { short = "c", description = "Path to config file", default = "placefs.toml" },
	},
	flags = {
		all = { short = "a", description = "Update all mapped assets" },
		["dry-run"] = { short = "n", description = "Preview changes without writing files" },
		quiet = { short = "q", description = "Suppress output except errors" },
	},
	subcommands = {
		setup = { description = "Create a new config file" },
		project = {
			description = "Generate a Rojo project file from your config",
			options = {
				output = { short = "o", description = "Output file path (derived from config name)" },
			},
		},
	},
	examples = {
		"pesde run placefs -- --all",
		"pesde run placefs -- -c builder.toml --all",
		"pesde run placefs -- game.Workspace.Maps game.Workspace.Parts",
		"pesde run placefs -- setup",
		"pesde run placefs -- setup -c builder.toml",
		"pesde run placefs -- project",
		"pesde run placefs -- project -c builder.toml",
	},
})

if args.subcommand == "setup" then
	require("./lib/setup")(args.options.config)
	return nil
end

if args.subcommand == "project" then
	require("./lib/generate_project")(args.options.config, args.options.output)
	return nil
end

-- Default command: sync assets from Roblox to filesystem
local config_path = process.cwd .. args.options.config

local config = load_sync_config(config_path)

local to_update = {}

if args.flags.all then
	for _, entry in config.map do
		table.insert(to_update, entry.robloxPath)
	end
elseif #args.positionals == 0 then
	print("[placefs] Error: No instances specified.")
	print("")
	print("Use '--all' to update all assets, or provide Roblox instance paths.")
	print("Run 'pesde run placefs -- --help' for usage information.")
	process.exit(1)
else
	for _, path in args.positionals do
		table.insert(to_update, normalizeRobloxPath(path))
	end
end

local failures = update_assets(config, to_update, {
	dryRun = args.flags["dry-run"],
	quiet = args.flags.quiet,
})

if failures > 0 then
	process.exit(1)
end

return nil
