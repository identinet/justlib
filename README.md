# justlib

Library of useful [Just task runner](https://just.systems/) recipes mainly
focused on software development and continuous integration.

## Usage

1. Clone repository as a submodule:
   `git submodule add https://github.com/identinet/justlib.git`
2. Import library into your `Justfile`, see [examples](#examples).
3. Install [nushell](https://www.nushell.sh/) dependency. This makes extensive
   use of nushell.
4. Start using recipes from library, e.g. `just format` to format your Justfile.

## Available recipes

```bash
just --list -f lib.just
```

```
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
    update-flake                      # Update flake

    [internal]
    format                            # Format Justfile
    githooks                          # Install git commit hooks

    [release]
    bump LEVEL="patch" NEW_VERSION="" # Bump version. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
    release                           # Build application and pushes image - run `just bump` first
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

_bump_files CURRENT_VERSION NEW_VERSION:
    #!/usr/bin/env nu
    # _bump_files is called by the bump recipe
    open package.json | upsert version "{{ NEW_VERSION }}" | save -f package.json; git add package.json

# Clean build folder
[group('development')]
clean:
    @rm -rvf "{{ DIST_FOLDER }}"
```
