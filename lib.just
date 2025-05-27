#!/usr/bin/env -S just --list --justfile
# Copyright 2024 - 2025, identinet GmbH. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Documentation Just: https://just.systems/man/en/
# Documentation Nushell: https://www.nushell.sh/book/

import './default.just'
import './docker.just'
import './ci.just'
import './nix.just'
import './bump.just'
