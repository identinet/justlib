# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT
#
# NIXOS_VERSION - See https://hub.docker.com/r/nixos/nix/tags

NIXOS_VERSION := '2.25.1'

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
