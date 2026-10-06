# Using neusis without the CLI

The CLI only writes files. Everything it generates is plain flake-parts
code you could write yourself. This page covers the pieces.

## Pick a flakeModule

| Import | You get |
|---|---|
| `neusis.flakeModules.default` | schema, `neusisOS` builders and the integration modules the builders reach for through `self.{nixos,darwin}Modules` (`hm-system-init`, `secrets`). Use this one. |
| `neusis.flakeModules.lib` | schema and builders only. A machine with users then fails with `attribute 'hm-system-init' missing` unless you define that module yourself. |
| `neusis.flakeModules.options` | the typed `flake.neusis.*` schema alone, for writing your own builders. |

Details: [flakeModules](../reference/flake-modules.md).

## Minimal flake

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    agenix-rekey.url = "github:oddlama/agenix-rekey";
    neusis.url = "github:leoank/neusis";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ self, ... }: {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.neusis.flakeModules.default ];

      flake.neusis.users.alice.neusisOS = {
        fullName = "Alice Example";
        machineToBundlesMap.box = [ ./homes/alice.nix ];
      };
      flake.neusis.registry.users.lab.admins = [ self.neusis.users.alice.neusisOS ];

      flake.neusis.machines.box = {
        system = "x86_64-linux";
        hostPubkey = "ssh-ed25519 AAAA…";
        userRegistries = [ self.neusis.registry.users.lab ];
        initialHashedPassword = ./secrets/hashedInitialPassword.age;
        # Must import inputs.agenix.nixosModules.default and
        # inputs.agenix-rekey.nixosModules.default: the initial password
        # is an agenix secret.
        module = ./hosts/box.nix;
      };
      flake.neusis.registry.machines.lab.nixos = [ self.neusis.machines.box ];

      flake = {
        inherit (self.neusis.lib.neusisOS.mkNeusisFlake {
          machineRegistries = self.neusis.registry.machines;
        }) nixosConfigurations darwinConfigurations homeConfigurations;
      };
    });
}
```

## Calling the builders directly

`mkNeusisFlake` is a loop over
[`mkNeusisOS`](../reference/lib/neusisOS.md#mkNeusisOS) and
[`mkNeusisDarwinOS`](../reference/lib/neusisOS.md#mkNeusisDarwinOS). You
can call them yourself for one-off hosts:

```nix
flake.nixosConfigurations.box = self.neusis.lib.neusisOS.mkNeusisOS {
  machineName = "box";
  userModule = ./hosts/box.nix;
  userRegistries = [ self.neusis.registry.users.lab ];
  initialHashedPassword = ./secrets/hashedInitialPassword.age;
};
```

All arguments are listed in [lib.neusisOS](../reference/lib/neusisOS.md).

## Modules à la carte

You don't need the schema to use neusis's modules. Any home-manager,
NixOS or nix-darwin configuration can import
`inputs.neusis.homeModules.<name>` or `inputs.neusis.nixosModules.<name>`
directly.
