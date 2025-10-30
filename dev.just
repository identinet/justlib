# Copyright 2025 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT
#
# These recipes are ment to be sourced by a Justfile in the root of a monorepository to quickly start application
# development.

SERVICES_DIRECTORY := "services"
SERVICES_IGNORE_FILE := ".noservice"

# Execute command in application
[group('development')]
_app_command APP *CMD:
    #!/usr/bin/env nu
    use std/log
    let service = ["{{ SERVICES_DIRECTORY }}" "{{ APP }}" ] | path join
    if not ($service | path exists) or ([$service "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists) {
        log error $"Service doesn't exist: ($service)"
        exit 1
    }
    log info $"Starting service: ($service)"
    cd $service
    load-env (direnv export json | from json) # load environment variables
    nix develop --command {{ CMD }}

# Start application
[group('development')]
dev APP:
    just _app_command "{{ APP }}" just dev

alias d := dev

# Start all applications
[group('development')]
dev-all:
    #!/usr/bin/env nu
    ls "{{ SERVICES_DIRECTORY }}" | where type == "dir" | get name |
      where (not ([$it "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists)) |
      str replace "{{ SERVICES_DIRECTORY }}/" "" | par-each {
        # Workaround if services access git or other services that use locks
        sleep ($"(random int 50..300)ms" | into duration)
        just dev $in
    }

alias da := dev-all

# List applications
[group('development')]
list:
    #!/usr/bin/env nu
    ls "{{ SERVICES_DIRECTORY }}" | where type == "dir" | get name |
      where (not ([$it "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists)) |
      str replace "{{ SERVICES_DIRECTORY }}/" "" | wrap service

alias ls := list

# Lint application's code
[group('lint')]
lint APP:
    just _app_command "{{ APP }}" just lint

alias l := lint

# Lint application's code and fix issues
[group('lint')]
lint-fix APP:
    just _app_command "{{ APP }}" just lint-fix

alias lf := lint-fix

# Lint all applications
[group('lint')]
lint-all:
    #!/usr/bin/env nu
    ls "{{ SERVICES_DIRECTORY }}" | where type == "dir" | get name |
      where (not ([$it "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists)) |
      str replace "{{ SERVICES_DIRECTORY }}/" "" | par-each {
        # Workaround if services access git or other services that use locks
        sleep ($"(random int 50..300)ms" | into duration)
        just lint $in
    }

alias la := lint-all

# Lint all applications and fix issues
[group('lint')]
lint-fix-all:
    #!/usr/bin/env nu
    ls "{{ SERVICES_DIRECTORY }}" | where type == "dir" | get name |
      where (not ([$it "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists)) |
      str replace "{{ SERVICES_DIRECTORY }}/" "" | par-each {
        # Workaround if services access git or other services that use locks
        sleep ($"(random int 50..300)ms" | into duration)
        just lint $in
    }

alias lfa := lint-fix-all
