# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT

import './_manifest.just'

# Automatically determines the repository URL

export GIT_CLIFF_REPO_URL := `git config --get remote.origin.url | sed -e 's#^git@#https://#' -e 's/\\.git$//'`

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
