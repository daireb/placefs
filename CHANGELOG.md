# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A sync refuses to save an asset that holds a `MaterialVariant` with a colour map but no compiled texture pack, which is what a place published while Studio is still compiling materials contains and which live servers draw as the plain base material. The asset's file on disk is left as it was, the variants are listed, the asset counts as a failure and placefs exits non-zero; other assets in the run still save.
- `--allow-unpacked-materials` saves such an asset anyway.

## [1.0.0]

### Added

- First-class multi-place configs using named `[places.<name>]` sections.
- Mappings are declared in a `[places.<name>.assets]` table keyed by Roblox path, with a plain string destination or a `{ path, maxExpansionDepth }` table.
- Unknown configuration keys are rejected, so a misnamed section is an error instead of a mapping that silently never syncs.
- Two keys in one place that resolve to the same Roblox path are rejected as duplicates.
- `--place`/`-p` selection and `PLACEFS_PLACE`/`PLACEFS_CONFIG` environment defaults.
- Filesystem-path targets, resolved back to Roblox paths within the selected place.
- `places` subcommand for listing configured places.
- Global and per-place `maxExpansionDepth` defaults.
- Safe instance-name validation for folder expansion.
- `ROBLOSECURITY` environment variable fallback when a Roblox Studio installation is unavailable, allowing placefs to run on CI runners.
- `PLACEFS_DEBUG` for printing a full traceback instead of a single-line error.

### Changed

- `--place` is optional when the config defines exactly one place, so single-place setups need no place selection at all.
- Subcommands are recognised after shared options, so `placefs -c other.toml places` runs the subcommand instead of treating `places` as a path to sync.
- Errors are reported as one `[placefs] Error: ...` line with a non-zero exit code rather than a Lune stack trace.
- `places` aligns its output columns.
- `--all` syncs the selected place, or every configured place sequentially when `--place` is omitted.
- Multi-place syncs isolate failures: a place that cannot be downloaded no longer aborts the places after it, and failed places are listed at the end.
- `project` names output files after places and generates every place when none is selected.
- `setup` appends a named place to an existing config while preserving its text.
- Mappings within a place are processed in sorted key order, so output is deterministic.
- Installation examples now pin the `v1.0.0` tag rather than tracking `main`.

### Breaking

The 0.x one-place shape is no longer accepted. placefs detects it and reports a
migration error; there is no compatibility path.

```toml
# 0.x
[settings]
placeId = 123456789

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"

[[assets]]
robloxPath = "game.Workspace.Props"
filesystemPath = "./assets/props"
maxExpansionDepth = 1
```

Give each old config file a place name, move `settings.placeId` onto it, and
turn each `[[assets]]` entry into a single keyed line. An entry that only sets
`filesystemPath` becomes a plain string; one that also sets options becomes a
table:

```toml
# 1.0
[places.maps]
placeId = 123456789

[places.maps.assets]
"game.Workspace.Map" = "./assets/map.rbxm"
"game.Workspace.Props" = { path = "./assets/props", maxExpansionDepth = 1 }
```

Additional 0.x config files become further `[places.<name>]` sections in the
same file. Note that `robloxPath` and `filesystemPath` no longer exist as keys:
the Roblox path is the key, and the filesystem path is the value.

## [0.6.0]

### Added

- Multi-place workflow support: use `-c`/`--config` with any command (`setup`, `project`, or sync) to target different config files.
- `--output`/`-o` flag on the `project` subcommand to control the output file path.
- Smart output naming: `project` derives the output filename and project name from the config file (e.g., `builder.toml` produces `builder.project.json`).

### Changed

- `--config`/`-c` is now a shared option available across all commands, replacing the positional argument on `setup` and `project`.
- Refactored the arg parser to support proper subcommand-specific flags and options.

## [0.5.1]

### Fixed

- `project` subcommand no longer sets `$className` on nodes whose `$path` points to a model file (`.rbxm`/`.rbxmx`), fixing a Rojo build error when instances directly to a file.

## [0.5.0]

### Added

- `project` subcommand: generates a `placefs.project.json` Rojo project file from your placefs config, enabling a round-trip workflow (Roblox -> filesystem -> Roblox).
- Subcommands section in `--help` output with descriptions for `setup` and `project`.
- Added the changelog.

For changes before 0.5.0, see the [commit history](https://github.com/daireb/placefs/commits/main).
