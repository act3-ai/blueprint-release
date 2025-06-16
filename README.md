# Release Blueprint

The release blueprint is a project blueprint for use with the ACT3 Project Tool. This blueprint defines best practices for releasing projects at ACT3 using dagger.

The blueprint setups up a three-stage release process capable of being ran locally or in the cloud:

- Prepare
  - Linters
  - Unit tests
  - Changelog and release notes
  - Semantic versioning
- Approve
  - Commit release materials
  - Tag release locally
- Publish
  - Push tag to remote
  - Create release page on remote, optionally with assets

The release process supports:

- Git Remotes
  - GitLab
  - GitHub
- Project Types
  - Go
  - Python
- Helm chart versioning and publishing
- Dockerfile image publishing

## Usage

Add the [Release Blueprint](https://github.com/act3-ai/blueprint-release) to your project by running the [**blueprint add** command](https://gitlab.com/act3-ai/asce/pt/-/blob/main/docs/cli/blueprint/add.md):

```sh
act3-pt blueprint add https://github.com/act3-ai/blueprint-release.git
```

## Quick Start

Complete the following steps to start using the [Release Blueprint](https://github.com/act3-ai/blueprint-release) in an existing GitHub or GitLab project:

1. **Clone** the project to your local machine
2. **Run** `cd <existing project name>`
3. **Run** `act3-pt blueprint add https://github.com/act3-ai/blueprint-release.git` to add the Blueprint
4. **Enter** values for the inputs of the Blueprint
5. **Commit** changes with `git add .project.yaml && git commit -m "<message>"`
6. **Run** `act3-pt blueprint render` to render the Blueprint's files
7. **Customize** the release process as desired, at a minimum setup access tokens. An `.envrc.private` file is recommended.
8. **Commit & Push** changes with `git push`

## Blueprint Inputs

The Release Blueprint defines the following inputs:

1. **host** (Required) - Release target host
   - Default value: repository URL host, e.g. github.com

2. **projectType** (Required) - Type of project
   - Suppored values: 'Go', 'Python'
   - Modifies release `prepare` for linting Go or Python files

3. **includeGoreleaser** (Optional) - Use `goreleaser` for release publish stage
   - Default value: 'disabled'
   - Supported values: 'disabled', 'enabled'
   - Only available for Go project type, python may be added in the future
   - Adds a `.goreleaser.yaml` file with a configuration suitable for repository host.
   - Additonal configuration may be necessary.

4. **executableName** (Optional) - Name of Go executable
   - Modifies `.goreleaser.yaml` for build executable name

5. **includeDockerPublish** (Optional) - Publish container image using Dockerfile
   - Modifies release `publish` stage to build a Dockerfile and push to an OCI registry
   - Additional configuration necessary to define OCI reference and registry token

6. **helmChartDir** (Optional) - Directory of Helm Chart
   - Modifies release `prepare` stage to bump version of helm chart
   - Modifies release `publish` for pushing helm chart to an OCI registry
   - Additional configuration necessary to define OCI reference and registry token

## Blueprint Files

The Release Blueprint contains files common to projects at ACT3:

- The script is located in `release.sh`, with usage docs available with `release.sh --help`. Most modifications should be limited to the scopes of `prepare`, `approve`, and `publish` functions.
- The changelog and release notes configuration file is located in `cliff.toml`. It may be used to configure how commit messages are parsed and used to build the changelog or release notes. See [git-cliff docs](https://git-cliff.org/docs/) for more information.
- Although the `prepare` stage runs various linters, this blueprint does NOT add configuration files for them. If the default configurations provided by each linter are not suitable please refer to each linters' documentation, see the [Config Files](#config-files) section.

## Further Configuration

This blueprint provides a base outline of a release process. The default usage of some tools may not be suitable depending on a project's requirements. Further configuration may be necessary, and is encouraged.

### Script

Although not required, modifications to `release.sh` should be limited to the scopes of the `prepare`, `approve`, and `publish` functions. Many of the components utilized are available as independent dagger modules, which may be used to replace the more comprehensive release module. Please refer to the documentation for each component for more information.

#### Dagger Modules

The main module used in `release.sh` is the [act3-ai/release](https://daggerverse.dev/mod/github.com/act3-ai/dagger/release) module. It's serves to wrap the following components into an easily configurable release pipeline.

External Modules:

- [shellcheck](https://daggerverse.dev/mod/github.com/dagger/dagger/modules/shellcheck)
- [golangci-lint](https://daggerverse.dev/mod/github.com/sagikazarmark/daggerverse/golangci-lint)
- [gh](https://daggerverse.dev/mod/github.com/sagikazarmark/daggerverse/gh) (GitHub CLI)
- [helm](https://daggerverse.dev/mod/github.com/sagikazarmark/daggerverse/helm)

Act3-ai Modules:

- [goreleaser](https://daggerverse.dev/mod/github.com/act3-ai/dagger/goreleaser)
- [git-cliff](https://daggerverse.dev/mod/github.com/act3-ai/dagger/git-cliff)
- [govulncheck](https://daggerverse.dev/mod/github.com/act3-ai/dagger/govulncheck)
- [docker](https://daggerverse.dev/mod/github.com/act3-ai/dagger/docker)
- [python](https://daggerverse.dev/mod/github.com/act3-ai/dagger/python)
- [yamllint](https://daggerverse.dev/mod/github.com/act3-ai/dagger/yamllint)
- [markdownlint](https://daggerverse.dev/mod/github.com/act3-ai/dagger/markdownlint)

### Config Files

To avoid cluttering a repository or introducing configurations not suitable for a project, this blueprint does not initialize config files for linters ran in the `prepare` stage. Although all linters will work "out-of-box", they will likely report many more issues than desired. Please refer to each linters' documentation for any changes necessary.

- [shellcheck wiki](https://github.com/koalaman/shellcheck/wiki), see 'Usage' section.
- [markdownlint-cli2 configuration](https://github.com/DavidAnson/markdownlint/blob/v0.32.1/README.md#configuration)
- [yamllint configuration](https://yamllint.readthedocs.io/en/stable/configuration.html)
- [golangci-lint configuration](https://golangci-lint.run/usage/configuration/)
- [uv docs](https://docs.astral.sh/uv/), all python linters are ran with `uv`