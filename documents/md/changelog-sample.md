# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `kestrel graph --json` for machine-readable dependency output.

## [2.3.0] - 2026-06-18

### Added

- Watch mode (`kestrel watch`) with debounced restarts.
- `needs` now accepts a task defined in another workspace package.

### Changed

- The cache key includes the resolved command string, so editing `run` invalidates it.
- Task output is streamed instead of buffered until exit.

### Fixed

- A task with no `inputs` is no longer cached forever (#412).
- Windows paths in `outputs` are normalized before hashing (#418).

## [2.2.1] - 2026-04-02

### Fixed

- `kestrel clean` refused to remove a directory that was already empty (#397).

### Security

- Updated the archive extractor to reject entries with absolute paths.

## [2.2.0] - 2026-02-11

### Added

- Coloured output, disabled automatically when stdout is not a TTY.

### Deprecated

- `kestrel build`, an alias for `kestrel run build`. It will be removed in 3.0.0.

## [2.1.0] - 2025-11-27

### Added

- Initial public release of the task cache.

### Removed

- The experimental `--parallel-unsafe` flag.

[Unreleased]: https://example.com/kestrel/compare/v2.3.0...HEAD
[2.3.0]: https://example.com/kestrel/compare/v2.2.1...v2.3.0
[2.2.1]: https://example.com/kestrel/compare/v2.2.0...v2.2.1
[2.2.0]: https://example.com/kestrel/compare/v2.1.0...v2.2.0
[2.1.0]: https://example.com/kestrel/releases/tag/v2.1.0
