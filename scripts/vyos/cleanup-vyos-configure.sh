#!/bin/bash

set -e
set -x

export DEBIAN_FRONTEND=noninteractive

# delete interfaces ethernet eth0 address
# delete interfaces ethernet eth0 hw-id
# delete system name-server

# hostname saved in the image, from image_hostname in the pkrvars file. vyos refuses other names
# at commit, which the vbash script below would not report, so check it here
IMAGE_HOSTNAME="${IMAGE_HOSTNAME:-vyosbuild}"
if [[ ! "${IMAGE_HOSTNAME}" =~ ^[A-Za-z0-9][-.A-Za-z0-9]*[A-Za-z0-9]$ || ${#IMAGE_HOSTNAME} -gt 63 ]]; then
    echo "$0 - error: image_hostname '${IMAGE_HOSTNAME}' is not a valid vyos host-name" >&2
    exit 1
fi

cat <<EOF > /home/vyos/cleanup-vyos.sh
#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
configure
set system host-name '${IMAGE_HOSTNAME}'
commit
save
exit
EOF
chmod 0700 /home/vyos/cleanup-vyos.sh
chown vyos:users /home/vyos/cleanup-vyos.sh
su - vyos -c "/home/vyos/cleanup-vyos.sh"

# run cleanup on vyos configure using python vyos.configtree, since can't remove interfaces via configure cli 
config_update_url="http://${PACKER_HTTP_IP}:${PACKER_HTTP_PORT}/cleanup-vyos-configure.py"
wget $config_update_url -O /home/vyos/cleanup-vyos-configure.py
chown vyos:users /home/vyos/cleanup-vyos-configure.py
chmod 0664 /home/vyos/cleanup-vyos-configure.py
python3 /home/vyos/cleanup-vyos-configure.py
rm -rf /home/vyos/cleanup-vyos-configure.py
