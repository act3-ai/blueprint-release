# Release Blueprint

The release blueprint is a project blueprint for use with the ACT3 Project Tool. This blueprint defines best practices for releasing projects at ACT3 using dagger.

The blueprint setups up a three-stage release process capable of being ran locally or in the cloud:

- Prepare
  - Linters
  - Unit tests
  - Changelog
  - Semantic versioning
- Approve
  - Commit release notes
  - Tag release locally
- Publish
  - Push tag to remote
  - Create release page on remote, optionally with assets

The release process supports:

- Git Remotes
  - GitLab
  - GitHub
- Project Types
  - Golang
  - Python