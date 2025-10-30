# justlib

Library of useful [Just task runner](https://just.systems/) recipes mainly
focused on software development and continuous integration.

## Depedencies

- [just](https://just.systems) task runner
- [git-cliff](https://git-cliff.org) changelog generator
- [gh](https://cli.github.com/) github cli
- [nushell](https://www.nushell.sh/) versatile shell
- [nix](https://nixos.org/) package manager for building docker images
- [deno](https://deno.com/) JS runtime for handling version bumps
- [git](https://git-scm.com/) source control management
- [docker](https://docker.com/) for running images
- [skopeo](https://github.com/containers/skopeo) for copying images to
  registries
- [direnv](https://direnv.net/) for loading environment configurations
- `file` for determining the mime type of build outputs

## Usage

1. Clone repository as a submodule:
   `git submodule add https://github.com/identinet/justlib.git`
2. Import library into your `Justfile`, see [examples](#examples).
   - Hint: The recipes are split into multiple files that can be imported
     individually.
3. Install [dependencies](#depedencies).
4. Start using recipes from library, e.g. `just format` to format your Justfile.

## Available recipes

### Individual application

Recipes meant for individual applications.

```bash
just --list -f lib.just
```

```
Available recipes:
    [ci]
    ci                                # CI pipeline task that will create a release of the package
    docker-build                      # Build image
    docker-inspect                    # Inspect image
    docker-inspect-registry           # Inspect image in registry
    docker-load                       # Load image locally
    docker-push                       # Push image
    docker-run                        # Run image locally
    docker-run-sh                     # Run shell image locally

    [development]
    dev APP                           # Start application
    dev-all                           # Start all applications
    list                              # List applications
    update-flake                      # Update flake

    [internal]
    format                            # Format Justfile
    githooks                          # Install git commit hooks

    [release]
    bump LEVEL="patch" NEW_VERSION="" # Bump version. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
    release                           # Build application and pushes image - run `just bump` first
```

### Mono repositories

Recipes meant for mono repositories that contain multiple applications. Import
these recipes only at the repository's root `Justfile`.

```bash
# Recipes meant for application development
just --list -f monorepo.just
```

## Examples

### Simple Exmple

```just
#!/usr/bin/env -S just --justfile
# Documentation: https://just.systems/man/en/
# Documentation: https://www.nushell.sh/book/

import 'justlib/lib.just'

# Print this help
default:
    @just -l
```

## Comprehensive Example

```just
#!/usr/bin/env -S just --justfile
# Documentation: https://just.systems/man/en/
# Documentation: https://www.nushell.sh/book/

import 'justlib/lib.just'

DIST_FOLDER := "dist"

# Print this help
default:
    @just -l

# Installs dependencies
[group('development')]
install: githooks
    deno install --frozen --lock

# Continuously run and build application for development purposes
[group('development')]
dev: install
    deno task dev

# Open URL in browser.
[group('development')]
open:
    deno run -A npm:open-cli "https://${EXTERNAL_HOSTNAME}"

# Build release version of application
[group('development')]
build: install
    deno task build

# Preview the build
[group('development')]
preview: build
    deno task preview

# Lint code
[group('linter')]
lint: githooks
    deno lint

# Lint code and fix issues
[group('linter')]
lint-fix: githooks
    deno lint --fix

# Update dependencies
[group('development')]
update-deps: githooks
    deno outdated --update --latest

# Sets new version in files files, called by `just bump`
[private]
[group('ci')]
_bump_files CURRENT_VERSION NEW_VERSION:
    #!/usr/bin/env nu
    open package.json | upsert version "{{ NEW_VERSION }}" | save -f package.json; git add package.json

# Clean build folder
[group('development')]
clean:
    @rm -rvf "{{ DIST_FOLDER }}"
```
