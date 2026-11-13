#!/bin/bash
#
# Runs inside the build container, started by build.sh. Not meant to be run on
# the host: it installs packages and clones into /src.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
    ca-certificates \
    devscripts \
    dh-python \
    git \
    procps \
    python3 \
    python3-all \
    python3-configobj \
    python3-dev \
    python3-httpretty \
    python3-jinja2 \
    python3-jsonpatch \
    python3-jsonschema \
    python3-netifaces \
    python3-oauthlib \
    python3-psutil \
    python3-pytest \
    python3-pytest-cov \
    python3-requests \
    python3-setuptools \
    python3-yaml

# full clone, no --depth: bddeb derives the package version from `git describe`
git clone "$CLOUD_INIT_REPO" /src
cd /src
git checkout "$CLOUD_INIT_REF"

echo "Building cloud-init package using bddeb..."
./packages/bddeb

echo "Done building:"
dpkg-deb -f cloud-init_all.deb Package Version Depends
cp cloud-init_all.deb /out/
