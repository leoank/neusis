# Concepts

## The dendritic layout

A neusis repo, neusis included, follows the *dendritic* pattern:

- **Every `.nix` file under `modules/` is a flake-parts module.**
  [`import-tree`](https://github.com/denful/import-tree) imports all of
  them, so file and directory names are just for organising. Files and
  directories whose names start with `_` are skipped. Use that for shared
  snippets or to park a module without deleting it.
- **`flake.nix` is generated.** Each module declares the inputs it needs in
  `flake-file.inputs = { … }`, and `nix run .#write-flake` writes them into
  `flake.nix`. Run it whenever you change an input, then
  `nix flake update <input>`.
- **Outputs reach each other through `self`.** A machine imports
  `self.darwinModules.secrets` or `self.neusis.features.darwin.theme`
  rather than a relative path.

## Machines

A machine is one entry in `flake.neusis.machines.<name>`:

```nix
flake.neusis.machines.laptop = {
  system = "aarch64-darwin";
  hostPubkey = "ssh-ed25519 AAAA…";        # agenix-rekey encrypts to this
  primaryUser = "alice";                   # darwin: system.primaryUser
  userRegistries = [ self.neusis.registry.users.home ];
  module = { ... }: {                      # the machine's NixOS / nix-darwin config
    imports = [ self.neusis.features.darwin.defaults ];
    system.stateVersion = 6;
  };
};
```

`userRegistries` lists the user labs whose members get accounts on this
machine. `module` is a normal NixOS or nix-darwin module. All fields are
listed in the [`flake.neusis.machines`](../reference/flake-schema.md#flakeneusismachines)
reference.

## Users

A user has two parts:

```nix
flake.neusis.users.alice = {
  # Who they are: account metadata.
  neusisOS = {
    fullName = "Alice Example";
    shell = "zsh";
    sshKeys = [ ./keys/alice.pub ];
    # Which home-manager bundles they get on which host.
    machineToBundlesMap = {
      laptop = [ self.neusis.users.alice.hmBundles.dev ];
      server = [ self.neusis.users.alice.hmBundles.minimal ];
    };
  };

  # Named home-manager module fragments. The names are up to you.
  hmBundles.dev = { … };
  hmBundles.minimal = { … };
};
```

Bundle names don't have to match machine names. The resolver only reads
`machineToBundlesMap`.

## Labs (registries)

A **lab** groups machines and users. A user lab sorts users by role:

| Role | Login | Linux groups |
|---|---|---|
| `admins` | yes | wheel, networkmanager, libvirtd, docker, podman, input, … |
| `regulars` | yes | libvirtd, docker, podman, input (no sudo) |
| `guests` | yes | input, docker, podman |
| `locked` | no (nologin, locked password; data kept) | input |

```nix
flake.neusis.registry.users.home.admins = [ self.neusis.users.alice.neusisOS ];
flake.neusis.registry.machines.home.darwin = [ self.neusis.machines.laptop ];
```

These lists merge across files. Each machine file and user file joins its
own lab, which is why `neusis add` only ever writes one new file. On darwin
the group sets are ignored.

## From data to configurations

`modules/systems.nix` passes the machine registry to
[`mkNeusisFlake`](../reference/lib/neusisOS.md#mkNeusisFlake):

```nix
let fleet = self.neusis.lib.neusisOS.mkNeusisFlake {
  machineRegistries = self.neusis.registry.machines;
};
in {
  flake.nixosConfigurations  = fleet.nixosConfigurations;
  flake.darwinConfigurations = fleet.darwinConfigurations;
  flake.homeConfigurations   = fleet.homeConfigurations;   # "<user>@<host>"
}
```

For each machine, `mkNeusisOS` (NixOS) or `mkNeusisDarwinOS` (nix-darwin):

1. evaluates the machine's `module`,
2. creates an account for every user in its `userRegistries`, with that user's role,
3. wires home-manager in and gives each user the bundles mapped to this
   hostname.

## Modules and features

neusis exports two kinds of reusable configuration:

- **Modules** declare options and do nothing until you enable them:
  `homeModules.*` for home-manager and `nixosModules.*` / `darwinModules.*`
  for systems. The system modules are platform-agnostic, so the same module
  works under both names. See the
  [home-manager](../reference/home-modules/index.md) and
  [system](../reference/system-modules/index.md) module references.
- **Features** (`neusis.features.<category>.<name>`) are config-only
  modules with no options. Importing one turns it on. They hold
  opinionated wiring such as Nix settings, macOS defaults or a tailscale
  mesh. See the [Features](../reference/features.md) reference.

The usual split is reusable mechanism in modules, opinions in features, and
machines and users picking what they want. Nothing is switched on for
everyone through shared defaults.
