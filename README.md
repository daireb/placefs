# placefs

Sync Roblox instances from published places to your local filesystem.

placefs is built for pulling the latest work from team-create builder places into a fully managed [Rojo](https://rojo.space/) project. One configuration can describe every place in an experience, while each place remains independently selectable.

Built with [Lune](https://lune-org.github.io/docs).

## Quick start

```bash
pesde add gh#daireb/placefs#v1.0.0
pesde run placefs -- setup          # prompts for a place name and ID
```

Then add your mappings to the generated `placefs.toml`:

```toml
[places.maps]
placeId = 84209236309122

[places.maps.assets]
"game.Workspace.Story" = "./assets/maps/story"
"game.Workspace.Props" = "./assets/props.rbxm"
```

And pull everything down:

```bash
pesde run placefs -- --all
```

placefs authenticates with the cookie from your Roblox Studio installation, so if you are logged into Studio there is nothing else to configure.

## Installation

```bash
pesde add gh#daireb/placefs#v1.0.0
```

Or add to your `pesde.toml`:

```toml
[dependencies]
placefs = { repo = "https://github.com/daireb/placefs", rev = "v1.0.0" }
```

## Configuration

Each place is a named section, and its mappings live in a table keyed by Roblox path:

```toml
[settings]
maxExpansionDepth = 2 # optional global default

[places.maps]
placeId = 84209236309122

[places.maps.assets]
"game.Workspace.Story" = { path = "./assets/maps/story", maxExpansionDepth = 1 }
"game.Workspace.Props" = "./assets/props.rbxm"

[places.lobby]
placeId = 92665231529109

[places.lobby.assets]
"game.Workspace.Map" = "./assets/maps/Lobby.rbxm"
```

The name you give a place is what you pass to `--place`, and it may contain letters, numbers, hyphens, and underscores.

Keys must be quoted, because TOML treats an unquoted dot as nesting. A value is either a filesystem path on its own, or a table when you need per-mapping options:

| Value form | Use |
| --- | --- |
| `"./assets/props.rbxm"` | Just a destination, everything else defaults |
| `{ path = "...", maxExpansionDepth = 1 }` | A destination plus options |

`maxExpansionDepth` can be set globally in `[settings]`, per place, or per mapping. The most specific value wins, and the built-in default is 2.

placefs rejects keys it does not recognise, so a misspelled or invented section is reported as an error rather than silently ignored.

### Single-file assets

A `.rbxm` or `.rbxmx` destination serializes an entire instance tree into one file:

```toml
[places.maps.assets]
"game.Workspace.Parts" = "./assets/parts.rbxm"
```

### Folder expansion

A destination without a model extension expands a Folder into a matching directory tree:

```toml
[places.maps.assets]
"game.Workspace.Maps" = { path = "./assets/maps", maxExpansionDepth = 2 }
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

## Setup

`setup` prompts for a place name and Roblox place ID, verifies you can access the place, and writes `placefs.toml`:

```bash
pesde run placefs -- setup
```

Run it again to append another place. Existing comments and formatting are preserved.

Use `-c` for a separate config, such as a personal scratch place:

```bash
pesde run placefs -- setup -c ~/scratch-placefs.toml
```

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

A positional beginning with `game.` or `workspace.` is interpreted as a Roblox path; all other positionals are filesystem paths.

Filesystem targets are resolved against the selected place's mappings. When the config defines more than one place, `--place` is required for positional paths so the target is never ambiguous. When it defines exactly one place, that place is used automatically and `--place` can be omitted everywhere:

```bash
# Single-place config: these are equivalent
pesde run placefs -- --place main game.Workspace.Map
pesde run placefs -- game.Workspace.Map
```

Preview a sync without writing:

```bash
pesde run placefs -- --place maps --dry-run --all
```

List configured places without accessing Roblox:

```bash
pesde run placefs -- places
```

### Material texture packs

Studio compiles a `MaterialVariant`'s texture pack some time after the variant changes, and live servers draw from the pack alone. A place published in between looks right in Studio, which falls back to the separate colour, normal and roughness maps, but its variants show as their plain base material in game.

Before saving an asset, placefs looks at every `MaterialVariant` at or under it. If any has a colour map but no texture pack, that asset fails: nothing is written for it, so what is on disk stays, the variants are listed in the summary and placefs exits non-zero. Other assets in the same run still save. A dry run reports the same failure.

To fix it, reopen the place in Studio, wait for the materials to finish compiling, publish and pull again. To save the asset as it is:

```bash
pesde run placefs -- --place maps --allow-unpacked-materials game.MaterialService
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
    -a, --all                       Update all mapped assets
        --allow-unpacked-materials  Save assets whose MaterialVariants have no texture pack
    -c, --config <VALUE>            Config path (default: placefs.toml; env: PLACEFS_CONFIG)
    -n, --dry-run                   Preview changes without writing files
    -h, --help                      Show help
    -p, --place <VALUE>             Configured place name (env: PLACEFS_PLACE)
    -q, --quiet                     Suppress output except errors
    -v, --version                   Show version

PROJECT OPTIONS:
    -o, --output <VALUE>   Output file path
```

`-c` and `--place` are shared across sync, `setup`, `places`, and `project`, and may be given before or after the subcommand. `PLACEFS_CONFIG` and `PLACEFS_PLACE` provide defaults that explicit CLI options override.

Errors are reported as a single `[placefs] Error: ...` line with a non-zero exit code. Set `PLACEFS_DEBUG=1` to print the full traceback instead when diagnosing a bug in the tool itself.

### Authentication

placefs downloads places as the logged-in user, so it needs a `.ROBLOSECURITY` cookie. It reads the cookie from your Roblox Studio installation first, and falls back to the `ROBLOSECURITY` environment variable when Studio is unavailable:

```bash
ROBLOSECURITY="$ROBLOX_COOKIE" pesde run placefs -- --all
```

The variable accepts either a bare token or the full `.ROBLOSECURITY=...` form, which makes placefs usable on CI runners and other machines without Studio installed.

### Running directly

```bash
lune run path/to/main.luau --place maps --all
lune run path/to/main.luau --all
```

## Development

Run the test suite with Lune from the repository root:

```bash
lune run tests/run
```

The suite is dependency-free and needs no network access. It covers argument parsing, config loading, target resolution, instance-name validation, the texture pack check, and a set of end-to-end checks that invoke the CLI as a subprocess to assert exit codes and error output.

Formatting and linting are pinned in `rokit.toml`, so run `rokit install` once and then:

```bash
stylua .          # format
stylua --check .  # verify formatting without writing
selene .          # lint
```

## Upgrading from 0.x

The 0.x single-place config shape is no longer accepted, and placefs reports a migration error if it finds one. See the [CHANGELOG](CHANGELOG.md) for the before-and-after config.

## License

MIT
