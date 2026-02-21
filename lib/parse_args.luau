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
}

--[[
	Represents a subcommand shown in help text.
	Subcommands are routed before arg parsing, so this is purely for display.
]]
export type SubcommandDef = {
	--- Usage hint shown after the subcommand name (e.g., "[PATH]")
	args: string?,
	--- Description shown in help text
	description: string,
}

--[[
	Configuration for the argument parser.
]]
export type ParserConfig = {
	--- Name of the CLI tool
	name: string,
	--- Version string
	version: string,
	--- Description shown in help text
	description: string,
	--- Subcommand definitions (for help text only)
	subcommands: { [string]: SubcommandDef }?,
	--- Flag definitions (boolean options)
	flags: { [string]: FlagDef }?,
	--- Option definitions (key-value options)
	options: { [string]: OptionDef }?,
	--- Usage examples shown in help text
	examples: { string }?,
}

--[[
	Result of parsing command line arguments.
]]
export type ParsedArgs = {
	--- Boolean flags that were set
	flags: { [string]: boolean },
	--- Options with their values
	options: { [string]: string },
	--- Positional arguments (non-flag/option arguments)
	positionals: { string },
}

local function printHelp(config: ParserConfig)
	print(`{config.name} v{config.version}`)
	print(config.description)
	print("")
	print("USAGE:")
	print(`    pesde run {config.name} -- [OPTIONS] [PATHS...]`)
	print(`    pesde run {config.name} -- <SUBCOMMAND>`)
	print("")

	if config.subcommands then
		print("SUBCOMMANDS:")

		local subcmdLines: { { name: string, desc: string } } = {}
		for name, def in config.subcommands do
			local display = if def.args then `{name} {def.args}` else name
			table.insert(subcmdLines, { name = display, desc = def.description })
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

	print("OPTIONS:")

	-- Collect all options for display
	local lines: { { short: string?, long: string, desc: string } } = {}

	-- Add user-defined flags
	if config.flags then
		for name, def in config.flags do
			table.insert(lines, {
				short = def.short,
				long = name,
				desc = def.description,
			})
		end
	end

	-- Add user-defined options
	if config.options then
		for name, def in config.options do
			local desc = def.description
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

	-- Add built-in flags
	table.insert(lines, { short = "h", long = "help", desc = "Show this help message" })
	table.insert(lines, { short = "v", long = "version", desc = "Show version" })

	-- Sort by long name
	table.sort(lines, function(a, b)
		return a.long < b.long
	end)

	-- Print formatted options
	for _, line in lines do
		local shortPart = if line.short then `-{line.short}, ` else "    "
		local longPart = `--{line.long}`
		-- Pad to align descriptions
		local padding = string.rep(" ", math.max(1, 22 - #longPart))
		print(`    {shortPart}{longPart}{padding}{line.desc}`)
	end

	-- Print examples if provided
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
	Parse command line arguments according to the provided configuration.
	
	Handles:
	- Long flags: --flag
	- Short flags: -f
	- Long options: --option=value or --option value
	- Short options: -o=value or -o value
	- Positional arguments
	
	Built-in support for --help/-h and --version/-v
]]
local function parseArgs(config: ParserConfig): ParsedArgs
	local flags: { [string]: boolean } = {}
	local options: { [string]: string } = {}
	local positionals: { string } = {}

	-- Initialize flags to false
	if config.flags then
		for name in config.flags do
			flags[name] = false
		end
	end

	-- Initialize options with defaults
	if config.options then
		for name, def in config.options do
			if def.default then
				options[name] = def.default
			end
		end
	end

	-- Build lookup tables for short forms
	local shortToFlag: { [string]: string } = {}
	local shortToOption: { [string]: string } = {}

	if config.flags then
		for name, def in config.flags do
			if def.short then
				shortToFlag[def.short] = name
			end
		end
	end

	if config.options then
		for name, def in config.options do
			if def.short then
				shortToOption[def.short] = name
			end
		end
	end

	local args = process.args
	local i = 1

	while i <= #args do
		local arg = args[i]

		if arg == "--help" or arg == "-h" then
			printHelp(config)
			process.exit(0)
		elseif arg == "--version" or arg == "-v" then
			printVersion(config)
			process.exit(0)
		elseif string.sub(arg, 1, 2) == "--" then
			-- Long form: --flag or --option=value or --option value
			local rest = string.sub(arg, 3)
			local eqPos = string.find(rest, "=")

			if eqPos then
				-- --option=value format
				local name = string.sub(rest, 1, eqPos - 1)
				local value = string.sub(rest, eqPos + 1)

				if config.options and config.options[name] then
					options[name] = value
				elseif config.flags and config.flags[name] then
					error(`Flag --{name} does not accept a value. Use --{name} without '='.`)
				else
					error(`Unknown option: --{name}. Use --help for usage information.`)
				end
			else
				-- --flag or --option value format
				local name = rest

				if config.flags and config.flags[name] then
					flags[name] = true
				elseif config.options and config.options[name] then
					-- Expect next argument to be the value
					i += 1
					if i > #args then
						error(`Option --{name} requires a value.`)
					end
					options[name] = args[i]
				else
					error(`Unknown option: --{name}. Use --help for usage information.`)
				end
			end
		elseif string.sub(arg, 1, 1) == "-" and #arg > 1 then
			-- Short form: -f or -o=value or -o value
			local rest = string.sub(arg, 2)
			local eqPos = string.find(rest, "=")

			if eqPos then
				-- -o=value format
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
				-- -f or -o value format
				local short = rest

				if shortToFlag[short] then
					flags[shortToFlag[short]] = true
				elseif shortToOption[short] then
					-- Expect next argument to be the value
					i += 1
					if i > #args then
						error(`Option -{short} requires a value.`)
					end
					options[shortToOption[short]] = args[i]
				else
					error(`Unknown option: -{short}. Use --help for usage information.`)
				end
			end
		else
			-- Positional argument
			table.insert(positionals, arg)
		end

		i += 1
	end

	return {
		flags = flags,
		options = options,
		positionals = positionals,
	}
end

return parseArgs
