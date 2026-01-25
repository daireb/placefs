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

1. Create a `placefs.toml` in your project root:

```toml
[settings]
placeId = 123456789  # Your published place ID

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
```

2. (Optional) Set your Roblox auth cookie as an environment variable if the auto-import fails:

```bash
export ROBLOSECURITY="your_cookie_here"
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

### CLI Options

```
OPTIONS:
    -a, --all              Update all mapped assets
    -c, --config <PATH>    Path to config file (default: placefs.toml)
    -n, --dry-run          Preview changes without writing files
    -q, --quiet            Suppress output except errors
    -h, --help             Show help message
    -v, --version          Show version
```

Preview what would be saved without writing files:

```bash
pesde run placefs -- --dry-run --all
```

Use a custom config file:

```bash
pesde run placefs -- --config custom.toml --all
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
