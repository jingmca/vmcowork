# Changelog

All notable changes to Cowork Sandbox will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [0.3.0] - 2026-01-25

### Added
- Network proxy monitoring tool (Phase 2 feature)
  - Real-time HTTP/HTTPS traffic monitoring
  - Detailed request logging with timestamps, URLs, status codes
  - Traffic statistics (request count, unique hosts, data transferred)
  - JSON log export functionality
  - Support for HTTPS CONNECT tunneling
- `cowork proxy` command with options:
  - `-l/--log` for file logging
  - `-v/--verbose` for detailed output
- Comprehensive proxy monitoring documentation (docs/03-proxy-monitoring.md)
- Statistical reporting (every 60 seconds)

### Changed
- Updated README with network monitoring features
- Enhanced CLI help with proxy command

## [0.2.0] - 2026-01-25

### Added
- Comprehensive documentation suite (USAGE.md, QUICKSTART.md, CONTRIBUTING.md)
- Automated test suite (scripts/test.sh)
- Python API examples (examples/basic_usage.py)
- Environment variable configuration template (.env.example)
- Project directory management with `-p` flag
- Conversation continuity with `-c` flag
- Support for third-party API configuration (ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL)
- Network proxy support (host:7890)
- Permission bypass mode (--dangerously-skip-permissions)
- Python controller API with full functionality
- CLI wrapper script (scripts/cowork)

### Changed
- Updated README with feature highlights and improved structure
- Enhanced sandbox.yaml with proxy configuration
- Improved VM provisioning scripts

### Fixed
- Lima 2.x JSON format compatibility in controller.py
- Workspace path fallback logic in cowork script

## [0.1.0] - Initial Release

### Added
- Basic VM setup with Lima
- Ubuntu 22.04 ARM64 support
- Pre-installed development tools (Python, Node.js, GCC, Java)
- File sharing between host and VM
- Interactive and non-interactive Claude Code modes
- VM lifecycle management (start, stop, status)
- Design documentation (docs/02-design.md)
- Research documentation (docs/01-research.md)
