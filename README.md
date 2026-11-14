# packer-vyos

HashiCorp Packer templates for building [VyOS](https://vyos.io) images.

`packer-vyos` builds customized VyOS images from an official VyOS ISO. It runs
the standard VyOS installer in a QEMU VM, applies configuration using the normal
`set` / `commit` workflow, and writes out a reusable `qcow2` image.

The project is intended for DevOps users who already understand Packer and want
a repeatable way to produce VyOS images for QEMU-compatible environments,
including Proxmox, Vagrant, VirtualBox, VMware, cloud platforms, and local labs.

## When to use this

Use `packer-vyos` when you want to:

- build a reusable VyOS `qcow2` image from an ISO;
- customize the image before first boot;
- install extra packages or agents;
- prepare an image for cloud-init;
- produce images for multiple virtualization targets using Packer.

If you want to build VyOS itself from source, use
[`vyos-build`](https://github.com/vyos/vyos-build).

## How the build works

1. You provide a VyOS ISO: LTS, rolling/nightly, or one built locally with
   `vyos-build`.
2. Packer boots the ISO in a QEMU VM.
3. The boot/login flow is driven over the console using the default
   `vyos` / `vyos` credentials.
4. The installer is run with `install image`.
5. Base networking is configured, typically with DHCP on `eth0`.
6. Customization scripts under `scripts/vyos/` are executed according to
   `vyos.pkr.hcl`.
7. Optional packages, agents, cloud-init support, and cleanup steps are applied.
8. The final image is written under `output-*/` and copied to `iso/` as a
   reusable `qcow2`.

When `headless=false`, Packer exposes a VNC server so you can watch or debug
the installer.

## Features

- Build VyOS images from official, rolling, or locally built ISOs
- Two-stage build flow: install first, customize second
- Add or remove Debian apt sources before installation
- Install custom packages with `apt`
- Install cloud-init from Debian, from the VyOS apt repository, or from a
  `.deb` built from the VyOS fork
- Run arbitrary shell or VyOS commands during customization
- Prepare images for cloud or template usage
- Install `qemu-guest-agent` and other virtualization agents
- Configure GRUB for KVM and serial console usage
- Toggle SSH and DHCP
- Configure interface address and default gateway
- Keep or replace the default `vyos` / `vyos` credentials
- Tune disk size and output image name
- Use the same Packer workflow for QEMU and other compatible builders

## Related projects

- [`pyvyos`](https://github.com/vyos-contrib/pyvyos) — Python SDK for the VyOS
  HTTPS API. Useful after the image boots, for automated configuration or
  testing.
- [`vyos-build`](https://github.com/vyos/vyos-build) — official VyOS build
  system for building VyOS images from source.
- [`vyos-vm-images`](https://github.com/vyos-legacy/vyos-vm-images) — Ansible-based
  VyOS VM image build automation. Archived in May 2024 and now read-only.

## Requirements

- Linux host with hardware virtualization.
- QEMU/KVM support.
- Packer.
- `make`.
- A VyOS ISO.
- `podman` or `docker`, only to build the cloud-init package from the VyOS fork
  (see [cloud-init](#cloud-init)). It can be on a different machine.

This project is developed and tested on Ubuntu 24.04 LTS. Debian should also
work. Other distributions may work but are not the primary target.

Check that hardware virtualization is available:

```bash
egrep '(vmx|svm)' /proc/cpuinfo
```

If running inside a Proxmox VM, enable host CPU passthrough so nested
virtualization is available:

```bash
qm set <vmid> --cpu host
```

For production builds, run on a dedicated Linux build host or a dedicated VM
with nested virtualization enabled.

### Packages

On Debian/Ubuntu:

```bash
apt install make qemu-system
```

For graphical debugging with VNC:

```bash
apt install tigervnc-viewer
```

For remote/headless debugging with a virtual X server:

```bash
apt install xvfb
```

## Usage

### Configuration

The build reads variables from:

1. `local-vyos-<version>.pkrvars.hcl`, if present (for example
   `local-vyos-1.4.pkrvars.hcl` for `make build1-1.4` and `make build2-1.4`);
2. otherwise `vyos-<version>.pkrvars.hcl`;
3. `.env`, if present.

The `local-` file replaces the shipped one instead of adding to it, so create
it by copying the shipped file.

Use `example.env` as the starting point for environment variables.

```bash
cp example.env .env
```

Edit `.env` and the relevant `.pkrvars.hcl` file before building.

### Initialize Packer

Run once before the first build:

```bash
make init
```

To upgrade Packer plugins:

```bash
make upgrade
```

### Provide the ISO

`build1-*` boots an ISO from `iso/`, and Packer verifies it against
`iso/SHA256SUM`. Both must exist before the first build.

1. Copy the VyOS ISO into `iso/` and name it `<vm_name>.iso`, where `vm_name`
   is the value in your `.pkrvars.hcl` file (for `vm_name =
   "vyos-1.4.0-epa3-amd64"`, the file is `iso/vyos-1.4.0-epa3-amd64.iso`).
2. Record its checksum in a `*.checksum` file and regenerate `iso/SHA256SUM`:

```bash
mkdir -p iso && cd iso
sha256sum vyos-1.4.0-epa3-amd64.iso > vyos-1.4.0-epa3-amd64.iso.checksum
cat *.checksum > SHA256SUM
cd ..
```

Use a `*.checksum` file rather than writing `SHA256SUM` by hand. Every build
regenerates `SHA256SUM` with `cat iso/*.checksum > iso/SHA256SUM`, which drops
any entry that is not in a `*.checksum` file.

### Build

The build has two stages:

- `build1-*`: boots the VyOS ISO and runs `install image`;
- `build2-*`: boots the installed disk image and applies customization.

Examples:

```bash
make build1-1.3 && make build2-1.3
make build1-1.4 && make build2-1.4
make build1-1.5 && make build2-1.5
```

Files in `iso/` (`<vm_name>` is the `vm_name` from your `.pkrvars.hcl` file):

```text
iso/<vm_name>.iso               input: the VyOS ISO you provide
iso/<vm_name>.iso.checksum      input: checksum of that ISO
iso/<vm_name>-build1.qcow2      build1 output: VyOS installed to disk
iso/<vm_name>-build2.qcow2      build2 working copy of the build1 image
iso/<vm_name>.img               final customized image (qcow2 format)
iso/SHA256SUM                   regenerated from iso/*.checksum on every build
```

`build1-*` also writes `.vm_name` in the repository root. `build2-*` reads it
to find the build1 image, so run `build1-*` first, with the same `vm_name`.

### cloud-init

`cloud_init` in your `.pkrvars.hcl` file selects where cloud-init comes from:

| Value           | cloud-init comes from                               |
|-----------------|-----------------------------------------------------|
| `debian`        | the Debian package (the default in the vars files)  |
| `vyos`          | the VyOS apt repository                             |
| `local_package` | a `.deb` you build from the VyOS fork               |
| `none`          | nowhere, cloud-init is not installed or changed     |

`vyos` currently fails: as of November 2026 the repository host named in
`http/debian_*-vyos.list` (`dev.packages.vyos.net`) does not resolve.

With `local_package`, cloud-init keeps the fork's own defaults: on first boot it
applies the datasource's network-config, hostname, users and SSH keys to the
VyOS configuration. The `debian` option disables cloud-init's network
configuration, and `vyos` also disables its config stage
(`scripts/vyos/cloud-init-*.sh`).

For `local_package`, build the package once, then set the variable:

```bash
make cloud-init-deb                        # VyOS 1.4 (sagitta)
make cloud-init-deb VYOS_RELEASE=circinus  # another release
```

```hcl
cloud_init = "local_package"
```

This writes `http/cloud-init_all.deb`. Packer serves it to the VM, which
installs it with apt. Options and details are in
[tools/cloud-init-deb](tools/cloud-init-deb/README.md).

If the machine that runs Packer has no container engine, build the package on
another machine and copy it over:

```bash
# on a machine with podman or docker
make cloud-init-deb
scp http/cloud-init_all.deb user@packer-host:/path/to/packer-vyos/http/
```

The package is architecture-independent (`Architecture: all`), so the build
machine can have a different CPU architecture, for example an Apple Silicon
Mac. In November 2026 a build in an arm64 container on a Mac produced a
byte-identical file to one built on x86-64 Linux.

### Build user credentials

The installer creates the `vyos` user with the password from `ssh_password`,
and Packer logs in with it during the build. The password hash is saved in the
image's configuration, so a deployed VM keeps accepting that login even if
cloud-init also creates other users.

To remove the user from the saved configuration at the end of the build, set
this in your `.pkrvars.hcl` file:

```hcl
remove_build_user = true
```

On first boot VyOS deletes the account, because it is not in the configuration.
VyOS itself only restores the default `vyos`/`vyos` account when `config.boot`
is missing, so the image has no login until cloud-init creates one.

With a seed, the logins come from its user-data. Without one, cloud-init does
not run and the image has no login, so use `remove_build_user` only for images
that always boot with a seed. For an image you want to log in to without a
seed, leave it `false`. To recover an image without a login, reset the password
from the GRUB menu.

Use `remove_build_user` with `cloud_init = "local_package"`, the only option
where cloud-init writes the seed's logins into the VyOS configuration. With
`debian` or `vyos` it likely leaves the image without a login even with a seed.
That is untested.

## Supported VyOS releases

`packer-vyos` can build from:

- VyOS LTS ISOs, available through a commercial subscription;
- VyOS rolling/nightly builds;
- locally built ISOs from `vyos-build`.

Common release branches:

- `equuleus` / 1.3
- `sagitta` / 1.4
- `circinus` / 1.5
- `current`

## Debugging and development

`headless=true` is the recommended default for automated builds.

Set `headless=false` when you want to watch the installer through VNC.

For local debugging, install a VNC client:

```bash
apt install tigervnc-viewer
```

For remote or headless hosts, start an X server with `Xvfb` and forward X11
over SSH:

```bash
ssh -X user@host
# or
ssh -Y user@host
```

Start the virtual X server:

```bash
make x11server
```

To attach a VNC viewer automatically, edit `vnc-connect.sh` and set a fixed
VNC port in `.env`:

```env
VNC_PORT_FIXED=5900
```

For SSH access into the temporary VM during a build, hold the VM after scripts
finish:

```env
SLEEP_BEFORE_SHUTDOWN=600
HOST_PORT_FIXED=2222
```

Then connect with:

```bash
ssh vyos@127.0.0.1 -p 2222
```

Default credentials are:

```text
username: vyos
password: vyos
```

## Notes

- The generated image may contain credentials or configuration from your local
  build variables. Treat build artifacts as sensitive.
- Do not publish customized images without reviewing the generated
  configuration.
- Use `local-vyos-<version>.pkrvars.hcl` for machine-local overrides. Git
  ignores these files.
- Prefer `headless=true` for repeatable automated builds.
