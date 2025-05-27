# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT

import './default.just'
import './_manifest.just'

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

# Build application and pushes image - run `just bump` first
[group('release')]
release: docker-push
