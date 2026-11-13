#!/bin/bash
#
# Build the VyOS fork of cloud-init (https://github.com/vyos/vyos-cloud-init)
# as a .deb inside a throwaway Debian container, and write it to http/ where
# Packer serves it to the VM when cloud_init = "local_package".
#
# All settings are optional and read from the environment:
#   VYOS_RELEASE      equuleus | sagitta | circinus | current  (default: sagitta)
#   BASE_IMAGE        container image to build in               (default: per release)
#   CLOUD_INIT_REF    branch, tag or commit to build            (default: per release)
#   CLOUD_INIT_REPO   git url of the fork   (default: https://github.com/vyos/vyos-cloud-init.git)
#   OUT_DIR           where cloud-init_all.deb is written       (default: <repo>/http)
#   CONTAINER_ENGINE  podman or docker                          (default: podman, else docker)

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$here/../.." && pwd)

VYOS_RELEASE=${VYOS_RELEASE:-sagitta}

case "$VYOS_RELEASE" in
    equuleus) default_base=debian:bullseye; default_ref=equuleus ;;
    sagitta)  default_base=debian:bookworm; default_ref=sagitta-public-unmaintained ;;
    circinus) default_base=debian:bookworm; default_ref=circinus-public-unmaintained ;;
    current)  default_base=debian:bookworm; default_ref=rolling ;;
    *)
        echo "$0 - error: unsupported VYOS_RELEASE '$VYOS_RELEASE'" >&2
        exit 1
        ;;
esac

BASE_IMAGE=${BASE_IMAGE:-$default_base}
CLOUD_INIT_REF=${CLOUD_INIT_REF:-$default_ref}
CLOUD_INIT_REPO=${CLOUD_INIT_REPO:-https://github.com/vyos/vyos-cloud-init.git}
OUT_DIR=${OUT_DIR:-$repo_root/http}
CONTAINER_ENGINE=${CONTAINER_ENGINE:-$(command -v podman || command -v docker || true)}

if [[ -z "$CONTAINER_ENGINE" ]]; then
    echo "$0 - error: neither podman nor docker found, set CONTAINER_ENGINE" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
out_dir=$(cd "$OUT_DIR" && pwd)

echo "building cloud-init $CLOUD_INIT_REF in $BASE_IMAGE with $CONTAINER_ENGINE"

# the build script is passed as an argument rather than on stdin, so that
# nothing inside the container can swallow it by reading stdin
"$CONTAINER_ENGINE" run --rm \
    -e CLOUD_INIT_REPO="$CLOUD_INIT_REPO" \
    -e CLOUD_INIT_REF="$CLOUD_INIT_REF" \
    -v "$out_dir:/out:rw,z" \
    "$BASE_IMAGE" \
    bash -c "$(cat "$here/container-build.sh")"

echo "wrote $out_dir/cloud-init_all.deb"
