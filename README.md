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
- Install cloud-init, either upstream Debian or VyOS-patched variants
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

1. `local.pkrvars.hcl`, if present;
2. otherwise `vyos.pkrvars.hcl`;
3. `.env`, if present.

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

Generated files:

```text
iso/vyos-X.Y.iso
iso/vyos-X.Y.qcow2
iso/SHA256SUM
```

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
- Use `local.pkrvars.hcl` for machine-local overrides and keep it out of git.
- Prefer `headless=true` for repeatable automated builds.
