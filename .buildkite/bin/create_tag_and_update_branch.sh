#!/bin/bash

set -eu

# $1 version
# $2 Push to branch option (TRUE|TAG_ONLY)

git config user.email "nativeappsdev@rokt.com"
git config user.name "nativeappsdev"

git tag -d "$1" || true
git checkout "${BUILDKITE_BRANCH}"
git pull
git add Package.swift
git add README.md
git commit -m "$1"
git tag -a "$1" -m "Automated release v$1"
git push origin "$1"
if [ "$2" != "TAG_ONLY" ]; then
    git push -f
fi