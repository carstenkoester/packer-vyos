#!/bin/bash

set -e
set -x

#GRUB_SERIAL=1
if [[ "${GRUB_SERIAL}" -ne 1 ]]; then
    echo "$0 - info: grub will keep default=0 (kvm). to use serial add to .env: GRUB_SERIAL=1"
    exit 0
fi

GRUB_CFG="/boot/grub/grub.cfg"
GRUB_DEFAULT="/etc/default/grub"
GRUB_VARS="/boot/grub/grub.cfg.d/20-vyos-defaults-autoload.cfg"

# 1.4 and later have one boot entry per image, the console comes from console_type in the vars
# file: tty (kvm, console=tty0) or ttyS (serial, console=ttyS0 only). the installer sets it from
# its console question, which the build1 template answers with K.
if [[ -f "${GRUB_VARS}" ]]; then
    sed -i 's/^set console_type=.*/set console_type="ttyS"/' $GRUB_VARS
    grep -q '^set console_type="ttyS"$' $GRUB_VARS
    exit 0
fi

# 1.3 has separate kvm and serial entries, the serial one is the second
sed -i 's/^set default=.*/set default=1/' $GRUB_CFG

if grep -q "^GRUB_DEFAULT=" $GRUB_DEFAULT; then
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=1/' $GRUB_DEFAULT
else
    echo "GRUB_DEFAULT=1" >> $GRUB_DEFAULT
fi

# update-grub


