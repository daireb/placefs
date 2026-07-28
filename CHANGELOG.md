# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0]

### Added

- First-class multi-place configs using named `[places.<name>]` sections.
- `--place`/`-p` selection and `PLACEFS_PLACE`/`PLACEFS_CONFIG` environment defaults.
- Filesystem-path targets, resolved back to Roblox paths within the selected place.
- `places` subcommand for listing configured places.
- Global and per-place `maxExpansionDepth` defaults.
- Safe instance-name validation for folder expansion.
- `ROBLOSECURITY` environment variable fallback when a Roblox Studio installation is unavailable, allowing placefs to run on CI runners.

### Changed

- `--all` syncs the selected place, or every configured place sequentially when `--place` is omitted.
- Multi-place syncs isolate failures: a place that cannot be downloaded no longer aborts the places after it, and failed places are listed at the end.
- `project` names output files after places and generates every place when none is selected.
- `setup` appends a named place to an existing config while preserving its text.
- Installation examples now pin the `v1.0.0` tag rather than tracking `main`.

### Breaking

The 0.x one-place shape is no longer accepted:

```toml
# 0.x
[settings]
placeId = 123456789

[[assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
```

Move each old config into a named place:

```toml
# 1.0
[places.maps]
placeId = 123456789

[[places.maps.assets]]
robloxPath = "game.Workspace.Map"
filesystemPath = "./assets/map.rbxm"
```

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
