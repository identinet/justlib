#!/usr/bin/env -S just --list --justfile
# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Documentation Just: https://just.systems/man/en/
# Documentation Nushell: https://www.nushell.sh/book/
#
# NIXOS_VERSION - See https://hub.docker.com/r/nixos/nix/tags

NIXOS_VERSION := '2.25.1'
MANIFEST := 'manifest.json'
export GIT_CLIFF_CONFIG := source_directory() / "cliff.toml"

# Automatically determines the repository URL

export GIT_CLIFF_REPO_URL := `git config --get remote.origin.url | sed -e 's#^git@#https://#' -e 's/\\.git$//'`

# Format Justfile
[group('internal')]
format:
    @just --fmt --unstable

# Install git commit hooks
[group('internal')]
githooks:
    #!/usr/bin/env nu
    $env.config = { use_ansi_coloring: false, error_style: "plain" }
    # Only install githooks in the repository's root folder
    let git_root = pwd | path split | reverse | drop (git rev-parse --show-toplevel | path split | length) | str join "/"
    if $git_root != "" {
        cd (git rev-parse --show-toplevel)
        just githooks
        return
    }
    let hooks_folder = '.githooks'
    let git_hooks_folder = do {git config core.hooksPath} | complete
    if $git_hooks_folder.stdout != $hooks_folder {
      print -e 'Installing git commit hooks'
      git config core.hooksPath $hooks_folder
      # npm install -g @commitlint/config-conventional
    }
    if not ($hooks_folder | path exists) {
      mkdir $hooks_folder
      "#!/usr/bin/env -S sh
    set -eu
    just test" | save $"($hooks_folder)/pre-commit"
      chmod 755 $"($hooks_folder)/pre-commit"
      "#!/usr/bin/env -S sh
    set -eu
    MSG_FILE=\"$1\"
    PATTERN='^(fix|feat|docs|style|chore|test|refactor|ci|build)(\\([A-Za-z0-9/_-]+\\))?!?: [a-z].+$'
    if ! head -n 1 \"${MSG_FILE}\" | grep -qE \"${PATTERN}\"; then
            echo \"Your commit message:\" 1>&2
            cat \"${MSG_FILE}\" 1>&2
            echo 1>&2
            echo \"The commit message must conform to this pattern: ${PATTERN}\" 1>&2
            echo \"Contents:\" 1>&2
            echo \"- follow the conventional commits style (https://www.conventionalcommits.org/)\" 1>&2
            echo 1>&2
            echo \"Example:\" 1>&2
            echo \"feat: add super awesome feature\" 1>&2
            exit 1
    fi" | save $"($hooks_folder)/commit-msg"
      chmod 755 $"($hooks_folder)/commit-msg"
      # if not (".commitlintrc.yaml" | path exists) {
      # "extends:\n  - '@commitlint/config-conventional'" | save ".commitlintrc.yaml"
      # }
      # git add $hooks_folder ".commitlintrc.yaml"
      git add $hooks_folder
    }

# Update flake
[group('development')]
update-flake:
    nix flake update

# Build image
[group('ci')]
docker-build: githooks
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    print -e $"Building image ($image)"
    # INFO: ?submodules=1# is required, see https://discourse.nixos.org/t/get-nix-flake-to-include-git-submodule/30324/3
    # Due to a bug, TMPDIR must be unset when running nix build inside a nix develop shell https://github.com/NixOS/nix/issues/10753
    TMPDIR= nix build '.?submodules=1#'

# Load image locally
[group('ci')]
docker-load: docker-build
    #!/usr/bin/env nu
    # support pre-built image and streamed
    let mimetype = file -L -i result | parse --regex "result: (?P<mimetype>[^;]+)" | $in.0.mimetype
    if $mimetype == "application/gzip" { cat ./result } else { ./result } | docker image load

# Run image locally
[group('ci')]
docker-run: docker-load
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    print -e (["Executing:" docker run -P --name $manifest.name -it --rm $image] | str join " ")
    docker run -P --name $manifest.name -it --rm $image

# Run shell image locally
[group('ci')]
docker-run-sh: docker-load
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = $"($manifest.registry.name)/($manifest.name):($manifest.version)"
    print -e (["Executing:" docker run -P --name $manifest.name -it --rm --entrypoint /bin/sh $image] | str join " ")
    docker run -P --name $manifest.name -it --rm --entrypoint /bin/sh $image

# Inspect image
[group('ci')]
docker-inspect: docker-build
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = {
      RepoTags: [$manifest.version],
      Name: $"($manifest.registry.name)/($manifest.name)",
      Digest: $"Refer to just docker-inspect-registry after pushing the image",
    }
    # support pre-built image and streamed
    let mimetype = file -L -i result | parse --regex "result: (?P<mimetype>[^;]+)" | $in.0.mimetype
    if $mimetype == "application/gzip" { cat ./result } else { ./result } | skopeo inspect --config docker-archive:/dev/stdin | from json | merge $image | table -e -w 120

# Inspect image in registry
[group('ci')]
docker-inspect-registry:
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = $"($manifest.registry.name)/($manifest.name)"
    print -e (["Executing:" skopeo inspect $"docker://($image):($manifest.version)"] | str join " ")
    let data = skopeo inspect $"docker://($image):($manifest.version)" | from json
    $data | merge { Image: $"($image):($manifest.version)@($data | get -i Digest)" } | table -e -w 120

# Push image
[group('ci')]
docker-push: docker-build
    #!/usr/bin/env nu
    let manifest = (open "{{ MANIFEST }}")
    let image = $"($manifest.registry.name)/($manifest.name)"
    let mimetype = file -L -i result | parse --regex "result: (?P<mimetype>[^;]+)" | $in.0.mimetype
    if $mimetype == "application/gzip" { cat ./result } else { ./result } | skopeo copy docker-archive:/dev/stdin $"docker://($image):($manifest.version)"
    just docker-inspect-registry

# Bump version. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
[group('release')]
bump LEVEL="patch" NEW_VERSION="":
    #!/usr/bin/env nu
    if (git rev-parse --abbrev-ref HEAD) != "main" {
      print -e "ERROR: A new release can only be created on the main branch."
      exit 1
    }
    if (git status --porcelain | wc -l) != "0" {
      print -e "ERROR: Repository contains uncommited changes."
      exit 1
    }
    # str replace -r "-.*" "" - strips git's automatic prerelease version
    let manifest = (open "{{ MANIFEST }}")
    # let current_version = (git describe | str replace -r "-.*" "" | deno run npm:semver $in)
    let current_version = ($manifest.version |  deno run npm:semver $in)
    let new_version = if "{{ NEW_VERSION }}" == "" {$current_version | deno run npm:semver -i "{{ LEVEL }}" $in | lines | get 0} else {"{{ NEW_VERSION }}"}
    print "\nChangelog:\n"
    git cliff --strip all -u -t $new_version
    input -s $"Version will be bumped from ($current_version) to ($new_version)\nPress enter to confirm.\n"
    just _bump_files $current_version $new_version
    git cliff -t $new_version -o CHANGELOG.md; git add CHANGELOG.md
    git commit -n -m $"Release version ($new_version)"
    let new_tag = pwd | path split | reverse | drop (git rev-parse --show-toplevel | path split | length) | reverse | append $new_version | str join "/"
    git tag -s -m $new_tag $new_tag
    git push --atomic origin refs/heads/main $"refs/tags/($new_tag)"
    git cliff --strip all --current | gh release create -F - $new_tag

# Build application and pushes image - run `just bump` first
[group('release')]
release: docker-push

# CI pipeline task that will create a release of the package
[group('ci')]
ci:
    docker run -w "/app" -v "${PWD}:/app" -v "${DOCKER_CONFIG:-${HOME}/.docker}/config.json:/root/.docker/config.json" "nixos/nix:{{ NIXOS_VERSION }}" /bin/sh -c "nix-env -iA nixpkgs.just; just _ci"

# Release task that can only be executed within a NixOS environment
_ci:
    # Enable experimental flakes feature
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
    # Workaround if git directory doesn't belong to the current user, see bug https://github.com/NixOS/nix/issues/10202
    git config --global --add safe.directory "/app"
    mkdir -p /etc/containers
    # See https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md
    # Disable all container security by default
    echo '{ "default": [ { "type": "insecureAcceptAnything" } ] }' > /etc/containers/policy.json
    nix develop .#ci --command just release

# vi: ft=just
