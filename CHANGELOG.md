# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-10-14

### Added
- `corebook-x-audio-fix.sh` with an interactive menu: install, uninstall (rollback), and a live test.
- HDA patch file that enables pin `0x1b` as an internal speaker (`0x90170150`) on the Realtek ALC269VC (`0x1e507036`).
- Hardware check to stop on unsupported machines.
- Full logging of commands and output to `corebook-x-audio-fix.log`.
- Automatic backup of existing files before install.
