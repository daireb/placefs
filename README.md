# placefs

Sync Roblox instances from published places to your local filesystem.

placefs is built for pulling the latest work from team-create builder places into a fully managed [Rojo](https://rojo.space/) project. One configuration can describe every place in an experience, while each place remains independently selectable.

Built with [Lune](https://lune-org.github.io/docs).

## Installation

```bash
pesde add gh#daireb/placefs#v1.0.0
```

Or add to your `pesde.toml`:

```toml
[dependencies]
placefs = { repo = "https://github.com/daireb/placefs", rev = "v1.0.0" }
```

## Authentication

placefs downloads places as the logged-in user, so it needs a `.ROBLOSECURITY` cookie. It reads the cookie from your local Roblox Studio installation first, and falls back to the `ROBLOSECURITY` environment variable when Studio is unavailable:

```bash
ROBLOSECURITY="$ROBLOX_COOKIE" pesde run placefs -- --all
```

The environment variable accepts either a bare token or the full `.ROBLOSECURITY=...` form, which makes placefs usable on CI runners and other machines without Studio installed.

## Setup

Run setup and enter a short name and Roblox place ID:

```bash
pesde run placefs -- setup
```

This verifies access and creates `placefs.toml`. Run it again to append another place without rewriting existing comments:

```bash
pesde run placefs -- setup
```

Use `-c` for a separate config, such as a personal scratch place:

```bash
pesde run placefs -- setup -c ~/scratch-placefs.toml
```

## Configuration

Places are keyed by the names used with `--place`:

```toml
[settings]
maxExpansionDepth = 2 # optional global default

[places.maps]
placeId = 84209236309122

[[places.maps.assets]]
robloxPath = "game.Workspace.Story"
filesystemPath = "./assets/maps/story"
maxExpansionDepth = 1

[places.lobby]
placeId = 92665231529109

[[places.lobby.assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/maps/Lobby.rbxm"
```

Place names may contain letters, numbers, hyphens, and underscores.

`maxExpansionDepth` can be set globally, per place, or per asset. The most specific value wins; the built-in default is 2.

### Single-file assets

Use a `.rbxm` or `.rbxmx` destination to serialize an entire instance tree as one file:

```toml
[[places.maps.assets]]
robloxPath = "game.Workspace.Parts"
filesystemPath = "./assets/parts.rbxm"
```

### Folder expansion

Use a destination without a model extension to expand a Folder into a matching directory tree:

```toml
[[places.maps.assets]]
robloxPath = "game.Workspace.Maps"
filesystemPath = "./assets/maps"
maxExpansionDepth = 2
```

This creates:

```text
assets/maps/
├── Level1/
│   ├── Spawn.rbxm
│   └── Props.rbxm
└── Level2/
    └── Terrain.rbxm
```

Folder children become filesystem segments exactly as named. Names containing `/`, `\`, or ending in `.rbxm`/`.rbxmx` are rejected because they cannot round-trip safely. Names containing `.` produce a warning because dotted Roblox paths cannot target them unambiguously.

## Syncing

Sync every mapped asset in one place:

```bash
pesde run placefs -- --place maps --all
```

Sync every configured place sequentially:

```bash
pesde run placefs -- --all
```

Places are synced independently: if one place cannot be downloaded, the remaining places still sync and the failure is reported at the end. placefs exits non-zero if any place failed.

Target one or more Roblox paths:

```bash
pesde run placefs -- --place maps game.Workspace.Story.Level3
```

Target the equivalent filesystem path, including a child that does not exist locally yet:

```bash
pesde run placefs -- --place maps assets/maps/story/Level3
```

Filesystem targets are resolved by the selected place's mappings, so `--place` is always required for positional paths. A positional beginning with `game.` or `workspace.` is interpreted as a Roblox path; all other positionals are filesystem paths.

Preview a sync without writing:

```bash
pesde run placefs -- --place maps --dry-run --all
```

List configured places without accessing Roblox:

```bash
pesde run placefs -- places
```

## Generating Rojo projects

Generate one project named for its place:

```bash
pesde run placefs -- project --place maps
# -> maps.project.json
```

Omit `--place` to generate one project for every configured place:

```bash
pesde run placefs -- project
```

Use `-o` to override the output for a selected place:

```bash
pesde run placefs -- project --place maps -o custom.project.json
```

`-o` cannot be used without `--place` when the config contains multiple places.

## CLI reference

```text
USAGE:
    pesde run placefs -- [OPTIONS] [PATHS...]
    pesde run placefs -- <SUBCOMMAND> [OPTIONS]

SUBCOMMANDS:
    places                 List configured places
    project                Generate Rojo project files
    setup                  Add a place to the config

OPTIONS:
    -a, --all              Update all mapped assets
    -c, --config <VALUE>   Config path (default: placefs.toml; env: PLACEFS_CONFIG)
    -n, --dry-run          Preview changes without writing files
    -h, --help             Show help
    -p, --place <VALUE>    Configured place name (env: PLACEFS_PLACE)
    -q, --quiet            Suppress output except errors
    -v, --version          Show version

PROJECT OPTIONS:
    -o, --output <VALUE>   Output file path
```

`-c` and `--place` are shared across sync, `setup`, `places`, and `project`. `PLACEFS_CONFIG` and `PLACEFS_PLACE` provide defaults that explicit CLI options override.

### Running directly

```bash
lune run path/to/main.luau --place maps --all
lune run path/to/main.luau --all
```

## Migrating from 0.x

placefs 1.0 intentionally replaces one-file-per-place configuration. Move `settings.placeId` and each top-level `[[assets]]` entry under a named place:

```toml
# Before
[settings]
placeId = 123456789

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"

# After
[places.maps]
placeId = 123456789

[[places.maps.assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
```

Combine additional old config files as more `[places.<name>]` sections. The loader detects the old shape and reports a migration error; it does not maintain a second compatibility path.

## License

MIT
