#!/usr/bin/env bash

# For custom changes, see https://daggerverse.dev/mod/github.com/act3-ai/dagger/release for dagger release module usage.
{{- $private := "false" -}}
{{- if (and (ne .inputs.host "github.com") (ne .inputs.host "gitlab.com")) -}}
{{- $private = "true" -}}
{{end}}

# Custom Variables
version_path="VERSION"
changelog_path="CHANGELOG.md"
notes_dir="releases"
{{if (eq $private "true" ) -}}
netrc_file="~/.netrc"
goprivate="{{.inputs.host}}"
{{- end}}

# Remote Dependencies
mod_release="github.com/act3-ai/dagger/release@release/v0.1.2"
mod_gitcliff="github.com/act3-ai/dagger/git-cliff@git-cliff/v0.1.1"
{{if (and (eq .inputs.includeGoreleaser "enabled") (eq .inputs.projectType "Go")) -}}
mod_goreleaser="github.com/act3-ai/dagger/goreleaser@goreleaser/v0.1.0"
{{else if (eq .inputs.projectType "Python") -}}
mod_python="github.com/act3-ai/dagger/python@python/v0.1.1"
{{- end -}}
{{- if (eq .inputs.includeDockerPublish "enabled") -}}
mod_docker="github.com/act3-ai/dagger/docker@docker/v0.1.0"
{{- end}}
{{- if (ne .inputs.helmChartDir "") -}}
mod_helm="github.com/sagikazarmark/daggerverse/helm@helm/v0.14.0"
{{- end}}

help() {
    cat <<EOF

Name:
    release.sh - Run a release process in stages.

Usage:
    release.sh COMMAND [-f | --force] [-i | --interactive] [-s | --silent]  [--version VERSION] [-h | --help]

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

    --version VERSION
        Run the release process for a specific semver version, ignoring git-cliff's configured bumping strategy.

Required Environment Variables:
    TODO: Add as desired
    {{if (eq .inputs.host "github.com") -}}
    - GITHUB_API_TOKEN     - repo:api access
    {{- else -}}
    - GITLAB_API_TOKEN     - repo:api access
    {{- end}}
    {{if (and (eq .inputs.includeGoreleaser "enabled") (eq .inputs.projectType "Go")) -}}
    - RELEASE_LATEST       - tag release as latest
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
explicit_version=""  # release for a specific version

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
    "--version")
       shift
       explicit_version=$1
       shift
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
# disable read without -r backslash mangling for this func
# shellcheck disable=SC2162
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

# check_upstream ensures remote upstream matches local commit.
# Inputs:
#  - $1 : commit, often HEAD or HEAD~1
check_upstream() {
    if [ "$force" != "true" ]; then
        echo "Comparing local $1 to remote upstream"
        git diff "@{upstream}" "$1" --stat --exit-code
    fi
}

# prepare runs linters and unit tests, bumps the version, and generates the changelog.
# runs 'approve' if interactive mode is enabled.
prepare() {
    echo "Running prepare stage..."

    {{if (eq .inputs.projectType "Go") -}}
    old_version=v$(cat "$version_path")
    {{end}}
    # linters and unit tests
    {{if (eq .inputs.projectType "Other") -}}
    # TODO: See https://daggerverse.dev/search?q=act3-ai for available lint modules

    {{else -}}
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call {{lower .inputs.projectType}} check

    {{end -}}
    git fetch --tags
    check_upstream "HEAD"

    # bump version, generate changelogs
    vVersion=""
    if [ "$explicit_version" != "" ]; then
        vVersion="$explicit_version"
    else
        vVersion=$(dagger -m="$mod_gitcliff" -s="$silent" --src="." call bumped-version)
    fi

    dagger -m="$mod_release" -s="$silent" --src="." call prepare \
    --ignore-error="$force" \
    --version="$vVersion" \
    --version-path="$version_path" \
    --changelog-path="$changelog_path" \
    # if custom notes path, run git-cliff module with bumped version to resolve filename
    # --notes-path="${notes_dir}/${target_version}.md" \
    export --path="."

    vVersion=v$(cat "$version_path") # use file as source of truth
    {{if (eq .inputs.projectType "Go") -}}
    # verify release version with gorelease
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call go verify --target-version="$version" --current-version="$old_version"

    {{end}}
    echo -e "Successfully ran prepare stage.\n"
    echo -e "Please review the local changes, especially releases/$vVersion.md\n"
    if [ "$interactive" = "true" ] && [ "$(prompt_continue "approve")" = "true" ]; then
            approve
    fi
}

# approve commits changes and adds a release tag locally.
# runs 'publish' if interactive mode is enabled.
approve() {
    echo "Running approve stage..."

    git fetch --tags
    check_upstream "HEAD"

    vVersion=v$(cat "$version_path")
    notesPath="${notes_dir}/${vVersion}.md"

    # stage release material
    git add "$version_path" "$changelog_path" "$notesPath"
    git add \*.md
    {{if (ne .inputs.helmChartDir "")}}git add {{.inputs.helmChartDir}}/*{{end}}
    # signed commit
    git commit -S -m "chore(release): prepare for $vVersion"
    # annotated and signed tag
    git tag -s -a -m "Official release $vVersion" "$vVersion"

    echo -e "Successfully ran approve stage.\n"
    if [ "$interactive" = "true" ] && [ "$(prompt_continue "publish")" = "true" ]; then
            publish
    fi
}

# publish pushes the release tag, uploads release assets, and publishes images.
publish() {
    echo "Running publish stage..."

    git fetch --tags
    check_upstream "HEAD~1" # compare before our release commit, i.e. we're only fast forwarding that commit

    # push this branch and the associated tags
    git push --follow-tags

    vVersion=v$(cat "$version_path")

    {{ $repoinfo := ( .meta.repository | trimPrefix "https://" | trimSuffix ".git" | splitn "/" 3 ) -}}
    {{/* Release with goreleaser, for GitHub or GitLab */}}
    {{- if (and (eq .inputs.includeGoreleaser "enabled") (eq .inputs.projectType "Go")) -}}
    {{- if (eq .inputs.host "github.com") -}}
    dagger -m="$mod_goreleaser" -s="$silent" --src="." call \
    with-secret-variable --name="GITHUB_API_TOKEN" --secret=env:GITHUB_API_TOKEN \
    with-env-variable --name="RELEASE_LATEST" --value="$RELEASE_LATEST" \
    release

    {{else -}}
    dagger -m="$mod_goreleaser" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call \
    with-secret-variable --name="GITLAB_API_TOKEN" --secret=env:GITLAB_API_TOKEN \
    with-env-variable --name="RELEASE_LATEST" --value="$RELEASE_LATEST" \
    release

    {{- end -}}
    {{/* Basic releases with gh or glab CLIs */}}
    {{else if (eq .inputs.host "github.com") -}}
    dagger -m="$mod_release" -s="$silent" --src="." call create-github \
    --repo="{{$repoinfo._1}}/{{$repoinfo._2}}" \
    --token=env:GITHUB_API_TOKEN \
    --version="$vVersion" \
    --notes="releases/$vVersion.md" \
    # --assets=file1,file2,...

    {{else -}}
    dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call create-gitlab \
    --host="{{$repoinfo._0}}" \
    --project="{{$repoinfo._1}}/{{$repoinfo._2}}" \
    --token=env:GITLAB_API_TOKEN \
    --version="$vVersion" \
    --notes="releases/$vVersion.md" \
    # --assets=file1,file2,...

    {{end -}}
    {{if (eq .inputs.projectType "Python") -}}
    # publish python wheel
    # TODO: add OCI_REF, REG_USERNAME, and REG_PASSWORD
    dagger -m="$mod_python" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file" {{end}}call python publish \
    --publish-url="<OCI_REF>" \
    --username="<REG_USERNAME>" \
    --password=env:<REG_PASSWORD>

    {{end -}}
    {{if (ne .inputs.helmChartDir "") -}}
    dagger -m="$mod_helm" -s="$silent" call \
    with-registry-auth --address="<REGISTRY>" --username="<REG_USERNAME>" --secret=en:<REG_PASSWORD> \
    chart --source={{.inputs.helmChartDir}} \
    package \
    publish --registry="oci://<REGISTRY>/<REPO>/charts"

    {{end -}}
    # For resolving extra image tags, see https://daggerverse.dev/mod/github.com/act3-ai/dagger/release#Release.extraTags
    # extra_tags=$(dagger -m="$mod_release" -s="$silent" --src="." {{if (eq $private "true")}}--netrc="$netrc_file"{{end}} call release extra-tags --ref=<OCI_REF> --version="$version")
    # For applying extra image tags, see https://daggerverse.dev/mod/github.com/act3-ai/dagger/release#Release.addTags OR if the docker module is used, provide them directly to --tags
    
    {{if (eq .inputs.includeDockerPublish "enabled" ) -}}
    dagger -m="$mod_docker" -s="$silent" --src="." call \
    with-registry-creds --registry="<OCI_REG_REPO>" --username="<REG_USERNAME>" --password=env:<REG_PASSWORD> \
    with-label --name="<LABEL_KEY>" --value="<LABEL_VALUE>" \
    publish --address="<OCI_REG>" --tags="$vVersion" --platforms="linux/amd64,linux/arm64"

    {{else -}}
    # publish image
    # TODO:
    # - Docker dagger module - https://daggerverse.dev/mod/github.com/act3-ai/dagger/docker
    # - Native dagger containers - https://docs.dagger.io/cookbook#perform-a-multi-stage-build
    # - Or other methods

    {{end -}}

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