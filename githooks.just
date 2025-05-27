# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT

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
