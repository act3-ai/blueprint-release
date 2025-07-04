# Changelog

All notable changes to this project will be documented in this file.

## [0.1.7] - 2025-06-26

### 🐛 Bug Fixes (release.sh)

- *(release.sh)* Use file: prefix for netrc options as it's a dagger secret

## [0.1.6] - 2025-06-25

### 💼 Other

- Typo setting registry env var for helm publishing by @nathan-joslin
- Add plumbing for goprivate for go checks by @nathan-joslin
- Force skips linters in prepare by @nathan-joslin

### 📦 Dependencies

- Bump act3-ai dagger modules to latest versions by @nathan-joslin

## [0.1.5] - 2025-06-24

### 💼 Other

- Helm chart directory handling by @nathan-joslin

## [0.1.4] - 2025-06-24

### 💼 Other

- Add env vars for flags

## [0.1.3] - 2025-06-24

### 💼 Other

- Handling of RELEASE_LATEST if goreleaser option is enabled

## [0.1.2] - 2025-06-24

### 💼 Other

- Release.sh appease shellcheck

### 📦 Dependencies

- *(dagger)* Bump release module from v0.1.1 to v0.1.2
- *(blueprint,release.sh)* Bump python moduel from v0.1.0 to v0.1.1
- *(blueprint,release.sh)* Bump gorelease module from v0.1.0 to v0.1.1

## [0.1.1] - 2025-06-24

### 💼 Other

- Add cliff.toml to blueprint
- Conditional addition of old_version in release script
- Release.sh evaluation of force option
- Comparison of local HEAD to upstream

## [0.1.0] - 2025-06-23

🚀 Initial release 🚀
