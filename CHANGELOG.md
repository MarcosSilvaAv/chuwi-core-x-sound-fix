# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] - 2026-10-16

### Changed
- The codec subsystem ID (SSID) and address are now detected automatically, instead of being hard-coded to `0x1e507036`, and the installed patch uses the detected values ([#1](https://github.com/MarcosSilvaAv/chuwi-core-x-sound-fix/issues/1)).
- SSIDs that aren't confirmed yet are allowed after a warning and a confirmation prompt.

### Added
- Safety checks: pin `0x1b` must be an output pin, must not already be set by a kernel fix, and should be unused in the BIOS.
- The status screen shows the machine model, codec location and whether the SSID is confirmed.

## [1.0.0] - 2026-10-14

### Added
- `corebook-x-audio-fix.sh` with an interactive menu: install, uninstall (rollback), and a live test.
- HDA patch file that enables pin `0x1b` as an internal speaker (`0x90170150`) on the Realtek ALC269VC (`0x1e507036`).
- Hardware check to stop on unsupported machines.
- Full logging of commands and output to `corebook-x-audio-fix.log`.
- Automatic backup of existing files before install.
