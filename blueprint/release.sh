#!/usr/bin/env bash

# For custom changes, see https://daggerverse.dev/mod/github.com/act3-ai/dagger/release for dagger release module usage.

{{- $private := "false" -}}
{{- if (and (ne .inputs.host "github.com") (ne .inputs.host "gitlab.com")) -}}
{{- $private = "true" -}}
{{end -}}

{{if (eq $private "true" ) }}
# Custom Variables
netrc_file="~/.netrc"
goprivate="{{.inputs.host}}"
{{- end}}

# Remote Dependencies
mod_release="github.com/act3-ai/dagger/release"
{{if (and (eq .inputs.includeGoreleaser "enabled") (eq .inputs.projectType "Go")) -}}
mod_goreleaser="github.com/act3-ai/dagger/goreleaser"
{{else if (eq .inputs.projectType "Python") -}}
mod_python="github.com/act3-ai/dagger/python"
{{- end -}}
{{- if (eq .inputs.includeDockerPublish "enabled") -}}
mod_docker="github.com/act3-ai/dagger/docker"
{{- end}}

help() {
    cat <<EOF

Name:
    release.sh - Run a release process in stages.

Usage:
    release.sh COMMAND [-f | --force] [-i | --interactive] [-s | --silent] [-h | --help]

Commands:
    prepare - prepare a release locally by running linters, tests, and producing the changelog, notes, assets, etc.

    approve - commit and tag your approved release.

    publish - push tag and publish the release to a remote by uploading assets, images, helm chart, etc.

Options:
    -h, --help
        Prints usage and other helpful information.

    -i, --interactive
        Run the release process interactively, prompting for approval to continue for each stage: prepare, approve, and publish. By default it begins with the prepare stage, otherwise it "resumes" the process at a specified stage.

    -s, --silent
        Run dagger silently, e.g. 'dagger --silent'.

    -f, --force
        Skip git status checks, e.g. uncommitted changes. Only recommended for development.

Required Environment Variables:
    {{if (eq .inputs.host "github.com") -}}
    - GITHUB_API_TOKEN     - repo:api access
    {{- else -}}
    - GITLAB_API_TOKEN     - repo:api access
    {{- end}}

Dependencies:
    - dagger
    - git
EOF
    exit 1
}

# insufficient args
if [ "$#" -eq 0 ]; then
    help
fi

set -euo pipefail

# Defaults
cmd=""
force=false       # skip git status checks
interactive=false # interactive mode
silent=false      # silence dagger (dagger --silent)

# Get commands and flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Commands
    "prepare" | "approve" | "publish")
        cmd=$1
        shift
        ;;
    # Flags
    "-h" | "--help")
      help
      ;;
    "-i" | "--interactive")
      interactive=true
      shift
      ;;
    "-s" | "--silent")
      silent=true
      shift
      ;;
    "-f" | "--force")
      force=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      help
      ;;
  esac
done

# Interactive mode begins with prepare by default, otherwise continue the release
# process at the specified stage. Must occur after parsing commands and flags, else
# we risk unexpected behavior, e.g. 'release.sh -f' would imply prepare.
if [ "$interactive" = "true" ] && [ -z "$cmd" ]; then
    cmd="prepare"
fi

# prompt_continue requests user input until a valid y/n option is provided.
# Inputs:
#   - $1 : name of next stage to continue to.
prompt_continue() {
    read -p "Continue to $1 stage (y/n)?" choice
    case "$choice" in
    y|Y )
        echo -n "true"
    ;;
    n|N )
        echo -n "false"
        ;;
    * )
        echo "Invalid input '$choice'" >&2
        prompt_continue "$1"
        ;;
    esac
}

# prepare runs linters and unit tests, bumps the version, and generates the changelog.
# runs 'approve' if interactive mode is enabled.
prepare() {
    echo "Running prepare stage..."

    old_version=v$(cat "$version_file")

    # linters and unit tests
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call {{lower .inputs.projectType}} check
    # bump version, generate changelogs
    git fetch --tags
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call prepare export --path="."

    version=v$(cat "$version_file")
    {{if (eq .inputs.projectType "Go") -}}
    # verify release version with gorelease
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call go verify --target-version="$version" --current-version="$old_version"
    {{- end}}

    echo -e "Successfully ran prepare stage.\n"
    echo -e "Please review the local changes, especially releases/$version.md\n"
    if [ "$interactive" = "true" ] && [ "$(prompt_continue "approve")" = "true" ]; then
            approve
    fi
}

# approve commits changes and adds a release tag locally.
# runs 'publish' if interactive mode is enabled.
approve() {
    echo "Running approve stage..."

    version=v$(cat "$version_file")
    notesPath="releases/$version.md"

    # stage release material
    git add "VERSION" "CHANGELOG.md" "$notesPath"
    git add \*.md
    # signed commit
    git commit -S -m "chore(release): prepare for $version"
    # annotated and signed tag
    git tag -s -a -m "Official release $version" "$version"

    echo -e "Successfully ran approve stage.\n"
    if [ "$interactive" = "true" ] && [ "$(prompt_continue "publish")" = "true" ]; then
            publish
    fi
}

# publish pushes the release tag, uploads release assets, and publishes images.
publish() {
    echo "Running publish stage..."

    # push this branch and the associated tags
    git push --follow-tags

    version=v$(cat "$version_file")

    {{ $repoinfo := ( .meta.repository | trimPrefix "https://" | trimSuffix ".git" | splitn "/" 3 ) -}}

    {{- if (and (eq .inputs.includeGoreleaser "enabled") (eq .inputs.projectType "Go")) -}}
    {{- if (eq .inputs.host "github.com") -}}
    dagger -m="$mod_goreleaser" -s="$silent" --src="." call \
    with-secret-variable --name="GITHUB_API_TOKEN" --secret=env:GITHUB_API_TOKEN \
    with-env-variable --name="RELEASE_LATEST" --value="$RELEASE_LATEST" \
    release
    {{- else -}}
    dagger -m="$mod_goreleaser" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file"{{end}} call \
    with-secret-variable --name="GITLAB_API_TOKEN" --secret=env:GITLAB_API_TOKEN \
    with-env-variable --name="RELEASE_LATEST" --value="$RELEASE_LATEST" \
    release
    {{- end -}}
    {{else if (eq .inputs.host "github.com") -}}
    dagger -m="$mod_release" -s="$silent" --src="." call create-github \
    --repo="{{$repoinfo._1}}/{{$repoinfo._2}}" \
    --token=env:GITHUB_API_TOKEN \
    --version="$version" \
    --notes="releases/$version.md" \
    # --assets=file1,file2,...
    {{else}}
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file"{{end}} call create-gitlab \
    --host="{{$repoinfo._0}}" \
    --project="{{$repoinfo._1}}/{{$repoinfo._2}}" \
    --token=env:GITLAB_API_TOKEN \
    --version="$version" \
    --notes="releases/$version.md" \
    # --assets=file1,file2,...
    {{- end}}

    {{- if (eq .inputs.projectType "Python") -}}
    # TODO: add OCI_REF, REG_USERNAME, and REG_PASSWORD
    dagger -m="$mod_python" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file"{{end}} call python publish \
    --publish-url="<OCI_REF>" \
    --username="<REG_USERNAME>" \
    --password=env:<REG_PASSWORD>
    {{- end}}

    # publish image
    # TODO:
    # - Docker dagger module - https://daggerverse.dev/mod/github.com/act3-ai/dagger/docker
    # - Native dagger containers - https://docs.dagger.io/cookbook#perform-a-multi-stage-build
    # - Or other methods
    #
    # For resolving extra image tags, see https://daggerverse.dev/mod/github.com/act3-ai/dagger/release#Release.extraTags
    # extra_tags=$(dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file"{{end}} call release extra-tags --ref=<OCI_REF> --version="$version")

    echo -e "Successfully ran publish stage.\n"
    echo "Release process complete."
}

# Run the release script.
case $cmd in
"prepare")
    prepare
    ;;
"approve")
    approve
    ;;
"publish")
    publish
    ;;
*)
    help
    ;;
esac