local process = require("@lune/process")

local parseArgs = require("./lib/parse_args")
local update_assets = require("./lib/update_assets")
local load_sync_config = require("./lib/load_sync_config")
local normalizeRobloxPath = require("./lib/normalize_path")

-- Parse command line arguments
local args = parseArgs({
	name = "placefs",
	version = "0.3.1",
	description = "Sync Roblox instances from a published place to your local filesystem",
	flags = {
		all = { short = "a", description = "Update all mapped assets" },
		["dry-run"] = { short = "n", description = "Preview changes without writing files" },
		quiet = { short = "q", description = "Suppress output except errors" },
	},
	options = {
		config = { short = "c", description = "Path to config file", default = "placefs.toml" },
	},
	examples = {
		"pesde run placefs -- game.Workspace.Maps game.Workspace.Parts",
		"pesde run placefs -- --all",
		"pesde run placefs -- --dry-run --all",
	},
})

-- Build config path
local config_path = process.cwd .. args.options.config

local config = load_sync_config(config_path)

local to_update = {}

if args.flags.all then
	-- Gather all robloxPaths from config
	for _, entry in config.map do
		table.insert(to_update, entry.robloxPath)
	end
elseif #args.positionals == 0 then
	-- No paths specified and --all not set
	print("[placefs] Error: No instances specified.")
	print("")
	print("Use '--all' to update all assets, or provide Roblox instance paths.")
	print("Run 'pesde run placefs -- --help' for usage information.")
	process.exit(1)
else
	-- Use provided paths (normalize to canonical format)
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
