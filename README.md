# placefs

Sync Roblox instances from a published place to your local filesystem.

Intended and built for easily downloading the latest updates from a teamcreate builder place onto your file-system for fully-managed [rojo](https://rojo.space/).

Built with [Lune](https://lune-org.github.io/docs).

## Installation

```bash
pesde add gh#daireb/placefs#main
```

Or add to your `pesde.toml`:

```toml
[dependencies]
placefs = { repo = "https://github.com/daireb/placefs", rev = "main" }
```

## Setup

Run the setup command to create a config file:

```bash
pesde run placefs -- setup
```

This will prompt for your place ID, verify you have access, and create `placefs.toml`.

You can specify a custom config path with `-c`:

```bash
pesde run placefs -- setup -c builder.toml
```

Then edit the generated file to add your asset mappings:

```toml
[settings]
placeId = 123456789

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
```

## Generating a Rojo project

Generate a Rojo project file from your config:

```bash
pesde run placefs -- project
```

This reads `placefs.toml` and generates `placefs.project.json`. The output filename is derived from the config name, so different configs produce different project files:

```bash
pesde run placefs -- project                        # placefs.toml -> placefs.project.json
pesde run placefs -- project -c builder.toml        # builder.toml -> builder.project.json
pesde run placefs -- project -o custom.project.json # explicit output name
```

This creates a [Rojo](https://rojo.space/) project file that maps your assets back to their Roblox locations, enabling a round-trip workflow:

```bash
# Pull assets from Roblox to your filesystem
pesde run placefs -- --all

# Generate a Rojo project from your config
pesde run placefs -- project

# Build back into a place file
rojo build placefs.project.json -o output.rbxl

# Or live-sync to Roblox Studio
rojo serve placefs.project.json
```

## Usage

Update specific instances:

```bash
pesde run placefs -- game.Workspace.Maps game.Workspace.Parts
```

Update all mapped assets:

```bash
pesde run placefs -- --all
```

### CLI Reference

```
SUBCOMMANDS:
    setup                 Create a new config file
    project               Generate a Rojo project file from your config

OPTIONS:
    -a, --all              Update all mapped assets
    -c, --config <VALUE>   Path to config file (default: placefs.toml)
    -n, --dry-run          Preview changes without writing files
    -h, --help             Show this help message
    -q, --quiet            Suppress output except errors
    -v, --version          Show version

PROJECT OPTIONS:
    -o, --output <VALUE>   Output file path (derived from config name)
```

The `-c`/`--config` option is shared across all commands:

```bash
pesde run placefs -- -c builder.toml --all
pesde run placefs -- setup -c builder.toml
pesde run placefs -- project -c builder.toml
```

Preview what would be saved without writing files:

```bash
pesde run placefs -- --dry-run --all
```

### Running directly

You can also run placefs directly with Lune without pesde:

```bash
lune run path/to/main.luau -- --all
lune run path/to/main.luau -- game.Workspace.Maps
```

## Configuration

### Single file mode

Serialize an entire instance tree as one `.rbxm` file:

```toml
[[assets]]
robloxPath = "game.Workspace.Parts"
filesystemPath = "./assets/parts.rbxm"
```

### Folder expansion mode

Expand a Folder's children into a directory structure:

```toml
[[assets]]
robloxPath = "game.Workspace.Maps"
filesystemPath = "./assets/maps"
maxExpansionDepth = 2  # optional, default: 2
```

This creates a directory mirroring the folder hierarchy:

```
assets/maps/
├── Level1/
│   ├── Spawn.rbxm
│   └── Props.rbxm
└── Level2/
    └── Terrain.rbxm
```

**Rules:**
- `filesystemPath` without extension → folder expansion (instance must be a Folder)
- `filesystemPath` with `.rbxm`/`.rbxmx` → single file (no expansion)
- `maxExpansionDepth` controls how deep to expand (any folders at the limit become `.rbxm` files)

### Targeted updates

Update specific instances within an expanded folder:

```bash
# Update just one child
pesde run placefs -- game.Workspace.Maps.Level1

# Update a deeply nested instance
pesde run placefs -- game.Workspace.Maps.Level1.Props
```

## Multi-place workflow

placefs supports syncing from multiple Roblox places using separate config files. Use `-c` to target a specific config across all commands:

```bash
# Set up configs for each place
pesde run placefs -- setup                     # -> placefs.toml
pesde run placefs -- setup -c builder.toml     # -> builder.toml

# Sync assets from each place
pesde run placefs -- --all                     # uses placefs.toml
pesde run placefs -- -c builder.toml --all     # uses builder.toml

# Generate Rojo projects (output names derived automatically)
pesde run placefs -- project                   # -> placefs.project.json
pesde run placefs -- project -c builder.toml   # -> builder.project.json

# Build each into a place file
rojo build placefs.project.json -o main.rbxl
rojo build builder.project.json -o builder.rbxl
```

## Example output

```
[placefs] Downloading place 123456789...
[placefs] Downloaded 2.4 MB in 3.2s
[placefs] Deserializing place...
[placefs] Deserialized in 0.8s
[placefs] Updating 3 instances...
[placefs] Saving: game.Workspace.Maps -> ./assets/maps
[placefs] Saving: game.Workspace.Parts -> ./assets/parts.rbxm

[placefs] Summary: 2 succeeded, 1 failed
[placefs] Errors:
  - game.Workspace.Missing: Instance not found at Roblox path: 'game.Workspace.Missing'
```

## License

MIT
