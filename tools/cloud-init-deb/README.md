# cloud-init-deb

Builds the [VyOS fork of cloud-init](https://github.com/vyos/vyos-cloud-init)
as a `.deb`, for images built with `cloud_init = "local_package"`.

The fork's own packaging script (`packages/bddeb`) needs Debian tooling, so the
build runs in a throwaway Debian container. Any host with `podman` or `docker`
works, including non-Debian ones.

## Usage

From the repository root:

```bash
make cloud-init-deb
```

or directly:

```bash
tools/cloud-init-deb/build.sh
```

The result is `http/cloud-init_all.deb`. Then set, in your `.pkrvars.hcl` file:

```hcl
cloud_init = "local_package"
```

and run `make build2-*` as usual.

## Options

All options are environment variables. With `make`, pass them as arguments, for
example `make cloud-init-deb VYOS_RELEASE=circinus`.

| Variable           | Default                                      | Meaning                          |
|--------------------|----------------------------------------------|----------------------------------|
| `VYOS_RELEASE`     | `sagitta`                                    | selects the defaults below       |
| `BASE_IMAGE`       | per release                                  | container image to build in      |
| `CLOUD_INIT_REF`   | per release                                  | branch, tag or commit to build   |
| `CLOUD_INIT_REPO`  | `https://github.com/vyos/vyos-cloud-init.git`| git URL of the fork              |
| `OUT_DIR`          | `http/` in the repository                    | where the `.deb` is written      |
| `CONTAINER_ENGINE` | `podman` if installed, else `docker`         | container engine to use          |

Defaults per `VYOS_RELEASE`:

| `VYOS_RELEASE` | `BASE_IMAGE`      | `CLOUD_INIT_REF`               |
|----------------|-------------------|--------------------------------|
| `equuleus`     | `debian:bullseye` | `equuleus`                     |
| `sagitta`      | `debian:bookworm` | `sagitta-public-unmaintained`  |
| `circinus`     | `debian:bookworm` | `circinus-public-unmaintained` |
| `current`      | `debian:bookworm` | `rolling`                      |

The defaults for `equuleus`, `circinus` and `current` are untested. Use the
same `VYOS_RELEASE` here as `vyos_release` in your vars file, so the package
matches the image's Debian release.

## How it works

1. `build.sh` starts the container and runs `container-build.sh` in it.
2. `container-build.sh` installs the build dependencies, clones the fork, checks
   out `CLOUD_INIT_REF` and runs `packages/bddeb`. The clone is fresh on every
   run and is not shallow, because the package version comes from `git describe`.
3. The resulting `cloud-init_all.deb` is copied to `OUT_DIR`, which is mounted
   into the container.
4. During `make build2-*`, Packer serves `http/` to the VM.
   `scripts/vyos/cloud-init-local-package.sh` downloads the `.deb` from there
   and installs it with apt. The Debian apt sources are enabled for this, so
   apt can resolve the package's dependencies.

To use a differently named file in `http/`, set `cloud_init_local_filename` in
your vars file.

## Building on another machine

The package is architecture-independent (`Architecture: all`), so it doesn't
have to be built where Packer runs, or on the same CPU architecture. If the
Packer host has no container engine, build on any machine that does and copy
the result into `http/` on the Packer host:

```bash
scp http/cloud-init_all.deb user@packer-host:/path/to/packer-vyos/http/
```

In November 2026 a build in an arm64 container on a Mac produced a
byte-identical file to one built on x86-64 Linux.
