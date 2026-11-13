
# vars:
# - .env                  building vars: control building process
# - vyos.pkrvars.hcl      image vars: define image parameters - git default
# - local.pkrvars.hcl     image vars: define image parameters - clone vyos.pkrvars.hcl to override it locally



ssh_username        = "vyos"
ssh_password        = "vyos"

# same as file name without .iso
vm_name             = "vyos-1.5-rolling-202405140019-amd64" 

# platform = "none" # will not install any specific platform
# - qemu will install qemu-guest-agent
platform            = "qemu"

# cloud-init values:
# debian - will install/replace cloud-init packages 
# vyos - will keep cloud-init packages from vyos
# local_package - will install the .deb named by cloud_init_local_filename
# comment - don't install cloud-init at all
cloud_init          = "debian"

# which kind of datasource should be used
# nocloud_configdrive => use this as default, will turn on NoCloud, ConfigDrive on cloud-init datasource_list
# blank - don't set default datasource_list
cloud_init_datasource = "nocloud_configdrive"

# cloud_init = "local_package" only: name of the cloud-init .deb in the http directory
# build it with tools/cloud-init-deb/build.sh
#cloud_init_local_filename = "cloud-init_all.deb"

# true: at the end of the build, remove the vyos user from the saved config, so the image has no
# known login credential. the image then has no login until cloud-init creates one on first boot,
# so it needs a seed
#remove_build_user = true

# Set grub_serial=1 to turn grub default=1, ie: use serial console. it is need to adjust on hypervisor
# 
# for proxmox:
#   qm set 9000 --serial0 socket --vga serial0
grub_serial         = 0

# equuleus:   debian 11 (branch 1.3.*)
# sagitta:    debian 12 (branch 1.4.*)
# circinus:   debian 12 (branch 1.5.*)
# current:    debian 12 (branch 1.5.*)
vyos_release        = "circinus"

# false will start vnc for console
headless            = false

# in MB (10GB x 1024 = 10240, minimum 2048)
disk_size           = 2048



# todo:
# - disable/enable ssh 
# - disable/enable dhcp
# - set interface/gateway 
# - keep vyos/vyos user/password or customize it
# - customize to install any other agent or package as needed like
# extra_packages      = []