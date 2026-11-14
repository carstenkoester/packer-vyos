#!/bin/bash

set -e
set -x

# the debian repos are needed whatever cloud_init is: apt-install.sh and platform-qemu.sh install
# debian packages, and local_package needs them for the dependencies of the .deb. only vyos skips
# this, its list (debian_*-vyos.list) has the debian entries too and apt-repo-vyos.sh installs it
if [[ "${CLOUD_INIT}" == "vyos" ]]; then
    echo "$0 - info: cloud_init vyos, apt-repo-vyos.sh sets up the debian repos too, skipping"
    exit 0
fi

# set debian list according VYOS_VERSION_MAIN
if [[ "$VYOS_RELEASE" == "equuleus" ]]; then
    debian_list_url="http://${PACKER_HTTP_IP}:${PACKER_HTTP_PORT}/debian_11.list"
elif [[ "$VYOS_RELEASE" == "current" || "$VYOS_RELEASE" == "sagitta" || "$VYOS_RELEASE" == "circinus" ]]; then
    debian_list_url="http://${PACKER_HTTP_IP}:${PACKER_HTTP_PORT}/debian_12.list"
else
    echo "vyos version unsupported, get github repo, fork and send a pull request"
    exit 1
fi

tmp_file=$(mktemp)

wget -O "$tmp_file" "$debian_list_url" || { echo "cant download debian.list from packer http repo"; exit 1; }

mv "$tmp_file" /etc/apt/sources.list.d/debian.list

apt update


#sudo bash -c 'echo "deb http://deb.debian.org/debian buster main contrib non-free" > /etc/apt/sources.list.d/debian.list'
#sudo bash -c 'echo "deb-src http://deb.debian.org/debian buster main contrib non-free" >> /etc/apt/sources.list.d/debian.list'
#sudo bash -c 'echo "deb http://security.debian.org/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list.d/debian.list'
#sudo bash -c 'echo "deb-src http://security.debian.org/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list.d/debian.list'
