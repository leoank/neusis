# Installation

## Prerequisites

- **Nix with flakes enabled.** Any recent installer works. The
  [Determinate installer](https://github.com/DeterminateSystems/nix-installer)
  enables flakes by default. With the upstream installer, add
  `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`.
- **git.** Nix only sees files that git tracks.
- **nix-darwin**, only for macOS hosts. You don't need to install it first;
  the first switch bootstraps it (see [Quickstart](quickstart.md#5-lock-and-switch)).

## Install the CLI

The `neusis` CLI writes files and never needs Nix to run. It does call
`nix` and `git` when they're available.

Prebuilt binary (Linux and macOS, all architectures):

```sh
curl -fsSL https://raw.githubusercontent.com/leoank/neusis/main/cli/install.sh | sh
```

The script reads `NEUSIS_VERSION` (pin a release) and `NEUSIS_INSTALL_DIR`
(where the binary goes).

With Nix, run the CLI without installing it:

```sh
nix run github:leoank/neusis#neusis -- init my-fleet
```

Or install it into your profile:

```sh
nix profile install github:leoank/neusis#neusis
```

Check that it works:

```sh
neusis version
```

## Without the CLI

The CLI is optional. A neusis fleet is an ordinary flake, and
[Using neusis without the CLI](library.md) shows how to write one by hand.
