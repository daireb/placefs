local process = require("@lune/process")

--[[
	Represents a flag definition (boolean option).
]]
export type FlagDef = {
	--- Short form of the flag (e.g., "a" for "-a")
	short: string?,
	--- Description shown in help text
	description: string,
}

--[[
	Represents an option definition (key-value option).
]]
export type OptionDef = {
	--- Short form of the option (e.g., "c" for "-c")
	short: string?,
	--- Description shown in help text
	description: string,
	--- Default value if not provided
	default: string?,
	--- Environment variable fallback
	env: string?,
}

--[[
	Represents a subcommand with its own flags and options.
]]
export type SubcommandConfig = {
	--- Description shown in help text
	description: string,
	--- Subcommand-specific flag definitions
	flags: { [string]: FlagDef }?,
	--- Subcommand-specific option definitions
	options: { [string]: OptionDef }?,
}

--[[
	Configuration for the argument parser.

	Top-level `options` are shared across all commands (including subcommands).
	Top-level `flags` apply only to the default command (no subcommand).
	Subcommands define their own flags/options via `SubcommandConfig`.
]]
export type ParserConfig = {
	--- Name of the CLI tool
	name: string,
	--- Version string
	version: string,
	--- Description shown in help text
	description: string,
	--- Subcommand definitions with their flags/options
	subcommands: { [string]: SubcommandConfig }?,
	--- Flag definitions for the default command
	flags: { [string]: FlagDef }?,
	--- Shared option definitions (available to all commands)
	options: { [string]: OptionDef }?,
	--- Usage examples shown in help text
	examples: { string }?,
}

--[[
	Result of parsing command line arguments.
]]
export type ParsedArgs = {
	--- The subcommand that was invoked, if any
	subcommand: string?,
	--- Boolean flags that were set
	flags: { [string]: boolean },
	--- Options with their values
	options: { [string]: string },
	--- Positional arguments (non-flag/option arguments)
	positionals: { string },
}

--- Renders a list of flag/option lines with aligned descriptions.
local function printOptionLines(lines: { { short: string?, long: string, desc: string } })
	table.sort(lines, function(a, b)
		return a.long < b.long
	end)

	for _, line in lines do
		local shortPart = if line.short then `-{line.short}, ` else "    "
		local longPart = `--{line.long}`
		local padding = string.rep(" ", math.max(1, 22 - #longPart))
		print(`    {shortPart}{longPart}{padding}{line.desc}`)
	end
end

--- Collects flag/option definitions into display lines.
local function collectOptionLines(
	flags: { [string]: FlagDef }?,
	options: { [string]: OptionDef }?
): { { short: string?, long: string, desc: string } }
	local lines: { { short: string?, long: string, desc: string } } = {}

	if flags then
		for name, def in flags do
			table.insert(lines, {
				short = def.short,
				long = name,
				desc = def.description,
			})
		end
	end

	if options then
		for name, def in options do
			local desc = def.description
			if def.env then
				desc = `{desc} (env: {def.env})`
			end
			if def.default then
				desc = `{desc} (default: {def.default})`
			end
			table.insert(lines, {
				short = def.short,
				long = `{name} <VALUE>`,
				desc = desc,
			})
		end
	end

	return lines
end

local function printHelp(config: ParserConfig)
	print(`{config.name} v{config.version}`)
	print(config.description)
	print("")
	print("USAGE:")
	print(`    pesde run {config.name} -- [OPTIONS] [PATHS...]`)

	if config.subcommands then
		print(`    pesde run {config.name} -- <SUBCOMMAND> [OPTIONS]`)
	end

	print("")

	if config.subcommands then
		print("SUBCOMMANDS:")

		local subcmdLines: { { name: string, desc: string } } = {}
		for name, def in config.subcommands do
			table.insert(subcmdLines, { name = name, desc = def.description })
		end

		table.sort(subcmdLines, function(a, b)
			return a.name < b.name
		end)

		for _, line in subcmdLines do
			local padding = string.rep(" ", math.max(1, 22 - #line.name))
			print(`    {line.name}{padding}{line.desc}`)
		end

		print("")
	end

	-- Main OPTIONS section: shared options + default command flags + built-in
	local mainLines = collectOptionLines(config.flags, config.options)
	table.insert(mainLines, { short = "h", long = "help", desc = "Show this help message" })
	table.insert(mainLines, { short = "v", long = "version", desc = "Show version" })

	print("OPTIONS:")
	printOptionLines(mainLines)

	-- Per-subcommand option sections
	if config.subcommands then
		for name, subcmd in config.subcommands do
			local hasFlags = subcmd.flags and next(subcmd.flags) ~= nil
			local hasOptions = subcmd.options and next(subcmd.options) ~= nil

			if hasFlags or hasOptions then
				local subcmdLines = collectOptionLines(subcmd.flags, subcmd.options)
				print("")
				print(`{string.upper(name)} OPTIONS:`)
				printOptionLines(subcmdLines)
			end
		end
	end

	if config.examples and #config.examples > 0 then
		print("")
		print("EXAMPLES:")
		for _, example in config.examples do
			print(`    {example}`)
		end
	end
end

local function printVersion(config: ParserConfig)
	print(`{config.name} {config.version}`)
end

--[[
	Resolves the effective flags and options for parsing, based on whether
	a subcommand was detected. Subcommand-specific flags/options are merged
	with the shared top-level options.
]]
local function resolveEffectiveConfig(
	config: ParserConfig,
	subcommandName: string?
): ({ [string]: FlagDef }?, { [string]: OptionDef }?)
	local effectiveFlags: { [string]: FlagDef }? = nil
	local effectiveOptions: { [string]: OptionDef }? = nil

	if subcommandName and config.subcommands then
		local subcmd = config.subcommands[subcommandName]
		effectiveFlags = subcmd.flags

		-- Merge shared options with subcommand options
		if config.options or (subcmd.options and next(subcmd.options) ~= nil) then
			effectiveOptions = {}
			if config.options then
				for k, v in config.options do
					effectiveOptions[k] = v
				end
			end
			if subcmd.options then
				for k, v in subcmd.options do
					effectiveOptions[k] = v
				end
			end
		end
	else
		effectiveFlags = config.flags
		effectiveOptions = config.options
	end

	return effectiveFlags, effectiveOptions
end

--[[
	Finds the subcommand token and its position, if one was given.

	Shared options may appear before the subcommand, so the scan skips over
	option values to avoid mistaking them for a subcommand. Only shared
	options are considered here, since subcommand-specific options cannot
	appear before the subcommand that defines them.
]]
local function findSubcommand(config: ParserConfig, rawArgs: { string }): (string?, number?)
	if not config.subcommands then
		return nil, nil
	end

	local sharedShorts: { [string]: boolean } = {}
	if config.options then
		for _, def in config.options do
			if def.short then
				sharedShorts[def.short] = true
			end
		end
	end

	local i = 1
	while i <= #rawArgs do
		local arg = rawArgs[i]

		if string.sub(arg, 1, 2) == "--" then
			local name = string.sub(arg, 3)
			-- An inline `--name=value` carries its own value
			if not string.find(name, "=") and config.options and config.options[name] then
				i += 1
			end
		elseif string.sub(arg, 1, 1) == "-" and #arg > 1 then
			local short = string.sub(arg, 2)
			if not string.find(short, "=") and sharedShorts[short] then
				i += 1
			end
		else
			-- The first bare argument is either the subcommand or a positional
			if config.subcommands[arg] then
				return arg, i
			end
			return nil, nil
		end

		i += 1
	end

	return nil, nil
end

--[[
	Parse command line arguments according to the provided configuration.

	If an argument matches a registered subcommand, the parser uses that
	subcommand's flags/options (merged with shared top-level options).
	Otherwise, top-level flags and options are used (default command).

	Built-in support for --help/-h and --version/-v.
]]
local function parseArgs(config: ParserConfig): ParsedArgs
	local flags: { [string]: boolean } = {}
	local options: { [string]: string } = {}
	local positionals: { string } = {}

	local rawArgs = process.args
	local subcommand, subcommandIndex = findSubcommand(config, rawArgs)

	-- Resolve which flags/options apply
	local effectiveFlags, effectiveOptions = resolveEffectiveConfig(config, subcommand)

	-- Initialize flags to false
	if effectiveFlags then
		for name in effectiveFlags do
			flags[name] = false
		end
	end

	-- Initialize options with defaults
	if effectiveOptions then
		for name, def in effectiveOptions do
			if def.env and process.env[def.env] and process.env[def.env] ~= "" then
				options[name] = process.env[def.env]
			elseif def.default then
				options[name] = def.default
			end
		end
	end

	-- Build lookup tables for short forms
	local shortToFlag: { [string]: string } = {}
	local shortToOption: { [string]: string } = {}

	if effectiveFlags then
		for name, def in effectiveFlags do
			if def.short then
				shortToFlag[def.short] = name
			end
		end
	end

	if effectiveOptions then
		for name, def in effectiveOptions do
			if def.short then
				shortToOption[def.short] = name
			end
		end
	end

	local i = 1

	while i <= #rawArgs do
		if i == subcommandIndex then
			i += 1
			continue
		end

		local arg = rawArgs[i]

		if arg == "--help" or arg == "-h" then
			printHelp(config)
			process.exit(0)
		elseif arg == "--version" or arg == "-v" then
			printVersion(config)
			process.exit(0)
		elseif string.sub(arg, 1, 2) == "--" then
			local rest = string.sub(arg, 3)
			local eqPos = string.find(rest, "=")

			if eqPos then
				local name = string.sub(rest, 1, eqPos - 1)
				local value = string.sub(rest, eqPos + 1)

				if effectiveOptions and effectiveOptions[name] then
					options[name] = value
				elseif effectiveFlags and effectiveFlags[name] then
					error(`Flag --{name} does not accept a value. Use --{name} without '='.`)
				else
					error(`Unknown option: --{name}. Use --help for usage information.`)
				end
			else
				local name = rest

				if effectiveFlags and effectiveFlags[name] then
					flags[name] = true
				elseif effectiveOptions and effectiveOptions[name] then
					i += 1
					if i > #rawArgs then
						error(`Option --{name} requires a value.`)
					end
					options[name] = rawArgs[i]
				else
					error(`Unknown option: --{name}. Use --help for usage information.`)
				end
			end
		elseif string.sub(arg, 1, 1) == "-" and #arg > 1 then
			local rest = string.sub(arg, 2)
			local eqPos = string.find(rest, "=")

			if eqPos then
				local short = string.sub(rest, 1, eqPos - 1)
				local value = string.sub(rest, eqPos + 1)

				if shortToOption[short] then
					options[shortToOption[short]] = value
				elseif shortToFlag[short] then
					error(`Flag -{short} does not accept a value. Use -{short} without '='.`)
				else
					error(`Unknown option: -{short}. Use --help for usage information.`)
				end
			else
				local short = rest

				if shortToFlag[short] then
					flags[shortToFlag[short]] = true
				elseif shortToOption[short] then
					i += 1
					if i > #rawArgs then
						error(`Option -{short} requires a value.`)
					end
					options[shortToOption[short]] = rawArgs[i]
				else
					error(`Unknown option: -{short}. Use --help for usage information.`)
				end
			end
		else
			table.insert(positionals, arg)
		end

		i += 1
	end

	return {
		subcommand = subcommand,
		flags = flags,
		options = options,
		positionals = positionals,
	}
end

return parseArgs
