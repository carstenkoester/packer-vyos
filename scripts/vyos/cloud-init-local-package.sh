#!/bin/bash

set -e
set -x

if [[ "${CLOUD_INIT}" != "local_package" ]]; then
    echo "$0 - info: cloud_init not local_package, skipping"
    exit 0
fi

if [[ -z "${CLOUD_INIT_LOCAL_FILENAME}" ]]; then
    echo "$0 - error: cloud_init_local_filename is empty"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# the .deb is served from the http directory, build it with tools/cloud-init-deb/build.sh
deb_url="http://${PACKER_HTTP_IP}:${PACKER_HTTP_PORT}/${CLOUD_INIT_LOCAL_FILENAME}"

tmp_dir=$(mktemp -d)
chmod 0755 "$tmp_dir"
deb_file="$tmp_dir/$(basename "$CLOUD_INIT_LOCAL_FILENAME")"

wget -O "$deb_file" "$deb_url" || { echo "cant download ${CLOUD_INIT_LOCAL_FILENAME} from packer http repo, build it with tools/cloud-init-deb/build.sh"; exit 1; }
chmod 0644 "$deb_file"

apt purge -y \
    cloud-init \
    cloud-utils \
    ifupdown

apt install -y \
    "$deb_file" \
    cloud-utils \
    ifupdown

rm -rf "$tmp_dir"

systemctl enable cloud-init

# keep the fork's own cloud.cfg.d/10_vyos.cfg: its config-stage modules apply the
# datasource's network-config, hostname, users and ssh keys to the vyos config.
# do not disable the config stage or the network config here, that turns them off.

rm -rf /etc/network/interfaces.d/50-cloud-init || :
