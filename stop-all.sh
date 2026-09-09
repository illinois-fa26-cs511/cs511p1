#!/bin/bash
# Spin the cluster down and remove its containers.

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

dc down "$@"
