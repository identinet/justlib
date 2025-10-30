# Copyright 2025 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT
#
# These recipes are ment to be sourced by a Justfile in the root of a monorepository to quickly start application
# development.

SERVICES_DIRECTORY := "services"
SERVICES_IGNORE_FILE := ".noservice"

# Start application
[group('development')]
dev APP:
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
    nix develop --command just dev

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

# List applications
[group('development')]
list:
    #!/usr/bin/env nu
    ls "{{ SERVICES_DIRECTORY }}" | where type == "dir" | get name |
      where (not ([$it "{{ SERVICES_IGNORE_FILE }}"] | path join | path exists)) |
      str replace "{{ SERVICES_DIRECTORY }}/" "" | wrap service
