# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT

import './_manifest.just'

# Automatically determines the repository URL

export GIT_CLIFF_REPO_URL := `git config --get remote.origin.url | sed -e 's#^git@#https://#' -e 's/\\.git$//'`

# Bump version. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
[group('release')]
bump LEVEL="patch" NEW_VERSION="":
    #!/usr/bin/env nu
    def dbg [] {
      let d = $in
      print $"data: ($d)"
      $d
    }
    let is_jj_repo = if (do -i {jj workspace root} | complete).exit_code == 0 { true } else { false }
    let is_main = if $is_jj_repo { do {jj log -r "trunk()::@" -T '"1\n"' --no-graph} | complete | $in.stdout | lines | length | $in > 0} else { do {git rev-parse --abbrev-ref HEAD} | complete | $in.stdout | str trim | $in in [main master] }
    if (not $is_main) {
      print -e "ERROR: A new release can only be created on the main branch."
      exit 1
    }
    # let is_empty = if $is_jj_repo { do {jj log -r @ -T 'if(empty, "empty")' --no-graph} | complete | $in.stdout ==
    # "empty" } else { do {git status --porcelain} | complete | $in.stdout | lines | length | $in == 0 }
    let is_empty = do {git status --porcelain} | complete | $in.stdout | lines | length | $in == 0
    if (not $is_empty) {
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
    git cliff -t $new_version -o CHANGELOG.md
    if not $is_jj_repo { git add -A }
    let msg = $"Release version ($new_version)"
    if $is_jj_repo { jj describe -m $msg } else { git commit -n -m $msg }
    let new_tag = pwd | path split | reverse | drop (git rev-parse --show-toplevel | path split | length) | reverse | append $new_version | str join "/"
    if $is_jj_repo { jj sign; jj tag set $new_tag } else { git tag -s -m $new_tag $new_tag }
    if $is_jj_repo { jj bookmark advance -t @-; jj git push; git push --tags } else { git push --atomic origin refs/heads/main $"refs/tags/($new_tag)" }
    let is_github = do {git remote get-url origin} | complete | $in.stdout | str trim | str contains github.com
    git cliff --strip all --current | if $is_github { gh release create -F - $new_tag } else { "Not creating a gitub release" }
