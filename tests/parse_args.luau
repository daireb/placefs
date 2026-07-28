local process = require("@lune/process")

local parseArgs = require("../lib/parse_args")

-- Mirrors the real placefs CLI shape so the tests exercise the same config
local CONFIG = {
	name = "placefs",
	version = "0.0.0",
	description = "test",
	options = {
		config = { short = "c", description = "Config path", default = "placefs.toml", env = "TEST_CONFIG" },
		place = { short = "p", description = "Place name", env = "TEST_PLACE" },
	},
	flags = {
		all = { short = "a", description = "All" },
		["dry-run"] = { short = "n", description = "Dry run" },
	},
	subcommands = {
		setup = { description = "Setup" },
		places = { description = "Places" },
		project = {
			description = "Project",
			options = {
				output = { short = "o", description = "Output" },
			},
		},
	},
}

local function parse(argv: { string })
	return parseArgs(CONFIG, argv)
end

local function expectError(argv: { string }, expected: string)
	local ok, message = pcall(parse, argv)
	assert(not ok, `Expected {table.concat(argv, " ")} to fail`)
	assert(
		tostring(message):find(expected, 1, true),
		`Expected error containing '{expected}', got '{tostring(message)}'`
	)
end

return function()
	-- Subcommand as the first argument
	local args = parse({ "places" })
	assert(args.subcommand == "places")
	assert(#args.positionals == 0)

	-- Subcommand after a long option with a separate value
	args = parse({ "--config", "other.toml", "places" })
	assert(args.subcommand == "places", "subcommand should be found after --config <value>")
	assert(args.options.config == "other.toml")
	assert(#args.positionals == 0, "subcommand token must not leak into positionals")

	-- Subcommand after a short option with a separate value
	args = parse({ "-c", "other.toml", "places" })
	assert(args.subcommand == "places", "subcommand should be found after -c <value>")
	assert(args.options.config == "other.toml")

	-- Subcommand after inline option values
	args = parse({ "--config=other.toml", "places" })
	assert(args.subcommand == "places" and args.options.config == "other.toml")

	args = parse({ "-c=other.toml", "places" })
	assert(args.subcommand == "places" and args.options.config == "other.toml")

	-- An option value that happens to match a subcommand name is still a value
	args = parse({ "-c", "places", "--all" })
	assert(args.subcommand == nil, "option value must not be treated as a subcommand")
	assert(args.options.config == "places")
	assert(args.flags.all == true)

	-- A flag before the subcommand does not consume it. Top-level flags belong
	-- to the default command only, so this now reports a clear error instead of
	-- silently treating "places" as a path to sync.
	expectError({ "--dry-run", "places" }, "Unknown option: --dry-run")

	-- The first bare argument decides: a non-subcommand word stays positional
	args = parse({ "foo", "places" })
	assert(args.subcommand == nil)
	assert(#args.positionals == 2 and args.positionals[1] == "foo" and args.positionals[2] == "places")

	-- Default command with positionals
	args = parse({ "game.Workspace.Map", "assets/thing" })
	assert(args.subcommand == nil)
	assert(#args.positionals == 2)
	assert(args.options.config == "placefs.toml", "default should apply")
	assert(args.flags.all == false, "flags default to false")

	-- Shared options remain available after a subcommand
	args = parse({ "project", "-c", "other.toml", "-o", "out.json" })
	assert(args.subcommand == "project")
	assert(args.options.config == "other.toml")
	assert(args.options.output == "out.json", "subcommand-specific option should parse")

	-- Subcommand-specific options are rejected on the default command
	expectError({ "-o", "out.json" }, "Unknown option: -o")

	-- Top-level flags do not apply inside a subcommand
	expectError({ "places", "--all" }, "Unknown option: --all")

	-- Malformed usage
	expectError({ "--bogus" }, "Unknown option: --bogus")
	expectError({ "--all=yes" }, "does not accept a value")
	expectError({ "--config" }, "requires a value")
	expectError({ "-c" }, "requires a value")

	-- Environment fallback, and CLI precedence over it
	process.env.TEST_PLACE = "from-env"
	args = parse({ "--all" })
	assert(args.options.place == "from-env", "env var should supply the default")

	args = parse({ "--place", "from-cli", "--all" })
	assert(args.options.place == "from-cli", "explicit CLI value must win over env")

	process.env.TEST_PLACE = nil
	args = parse({ "--all" })
	assert(args.options.place == nil, "unset env var should leave the option empty")
end
