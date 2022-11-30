#!/usr/bin/env bash

set -Eeuo pipefail
exec pre-commit "$@"
