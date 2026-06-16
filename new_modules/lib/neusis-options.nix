{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  # Per-user metadata. Each `flake.neusis.users.<name>` matches this
  # shape. `name` from the submodule binder is the attribute key, used
  # as the default `username`.
  userType = types.submodule (
    { name, ... }:
    {
      options = {
        neusisOS = mkOption {
          description = "Neusis-managed user metadata.";
          default = { };
          type = types.submodule {
            options = {
              username = mkOption {
                type = types.str;
                default = name;
                description = "System username. Defaults to the parent attribute name.";
              };
              fullName = mkOption {
                type = types.str;
                description = "Human-readable full name.";
              };
              shell = mkOption {
                type = types.str;
                default = "bash";
                description = "Login shell (e.g. bash, zsh, fish).";
              };
              sshKeys = mkOption {
                type = types.listOf types.path;
                default = [ ];
                description = "Public SSH key files authorized for this user.";
              };
              machineToBundlesMap = mkOption {
                type = types.lazyAttrsOf (types.listOf types.deferredModule);
                default = { };
                example = lib.literalExpression ''
                  {
                    rogue = [ self.neusis.users.ank.hmBundles.darwin
                              self.neusis.users.ank.hmBundles.dev ];
                  }
                '';
                description = ''
                  Map from machine hostname to the list of home-manager
                  module fragments to apply for this user on that host.
                  Entries are typically references into the user's
                  `hmBundles`, but any deferred module works.

                  Bundle names are independent of machine names — the
                  resolver only walks this map; it does not look up a
                  bundle whose name happens to match the hostname.
                '';
              };
            };
          };
        };

        hmBundles = mkOption {
          type = types.lazyAttrsOf types.deferredModule;
          default = { };
          description = ''
            Named bundles of home-manager module fragments for this
            user. Bundle names are arbitrary — they need not match
            machine hostnames. Reference them from
            `neusisOS.machineToBundlesMap` to select which bundles
            apply on which machine.
          '';
        };
      };
    }
  );

  # Per-lab user grouping by role.
  #
  # Each role list holds *user metadata attrsets* (typically references
  # to a `flake.neusis.users.<name>.neusisOS` value carrying
  # `username`, `sshKeys`, `machineToBundlesMap`, …). The earlier
  # `listOf deferredModule` typing here was a bug: `deferredModule`'s
  # merge wraps each value as `{ imports = [orig]; }`, so `mkAdmin`
  # saw `adminConfig.username` as missing. `listOf attrs` passes the
  # values through verbatim.
  userRegistryType = types.submodule {
    options = {
      admins = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = "Admin users — wheel/sudo, networkmanager, libvirtd, docker, podman.";
      };
      regulars = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = "Regular users — libvirtd, docker, podman (no wheel/sudo).";
      };
      locked = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = ''
          Locked users — accounts exist with data preserved but cannot login.
          Shell is forced to nologin and password is locked.
        '';
      };
      guests = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = "Guest users — minimal privileges (input, podman, docker).";
      };
    };
  };

  # Per-machine definition. Each `flake.neusis.machines.<name>` matches
  # this shape. The attribute key defaults to `hostname`.
  machineType = types.submodule (
    { name, ... }:
    {
      options = {
        hostname = mkOption {
          type = types.str;
          default = name;
          description = ''
            System hostname. Maps to `networking.hostName` and defaults
            to the parent attribute name.
          '';
        };

        computerName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Darwin-only friendly machine name shown in
            Sharing/Finder. Maps to `networking.computerName` on
            nix-darwin hosts and is ignored on NixOS.
          '';
        };

        hostPubkey = mkOption {
          type = types.str;
          description = ''
            SSH host public key for this machine. Used by agenix-rekey
            to encrypt per-host secrets.
          '';
        };

        system = mkOption {
          type = types.str;
          default = "x86_64-linux";
          example = "aarch64-darwin";
          description = ''
            Target system architecture for this machine (e.g.
            "x86_64-linux", "aarch64-linux", "aarch64-darwin"). Sets
            `nixpkgs.hostPlatform` on the system build and picks the
            `pkgs` used for this host's home-manager configurations.
          '';
        };

        nixpkgs = mkOption {
          type = types.nullOr types.raw;
          default = null;
          example = lib.literalExpression "inputs.nixpkgs-unstable";
          description = ''
            Optional override of the nixpkgs flake input used to build
            this machine. When `null`, the flake-wide `inputs.nixpkgs`
            is used. When set, both the NixOS system build (via this
            nixpkgs's `lib.nixosSystem`) and the host's home-manager
            `pkgs` are sourced from the override.

            Only honoured for NixOS hosts: `mkNeusisDarwinOS` asserts
            that this is `null`. nix-darwin's nixpkgs is determined by
            the `darwin` input's `nixpkgs.follows`, so per-machine
            overrides on Darwin require declaring a separate `darwin`
            input rather than a per-machine setting here.
          '';
        };

        primaryUser = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "ank";
          description = ''
            Primary user for this machine. On Darwin hosts,
            `mkNeusisDarwinOS` wires this through to nix-darwin's
            `system.primaryUser` (used by homebrew, user-scoped
            activation scripts, …). On NixOS hosts the field is
            currently ignored — declare it freely if you want a
            consistent way to identify "the main user" on either
            platform.

            Read it from any module via `config.system.primaryUser`
            once it has been set by the builder.
          '';
        };

        modulesSpecialArgs = mkOption {
          type = types.lazyAttrsOf types.raw;
          default = { };
          description = ''
            Extra `specialArgs` to thread into this machine's modules.
            Merged on top of the `inputs`/`outputs` that the system
            builders inject automatically.
          '';
        };

        module = mkOption {
          type = types.deferredModule;
          default = { };
          description = ''
            Root NixOS/nix-darwin module for this machine. Passed to
            `mkNeusisOS`/`mkNeusisDarwinOS` as `userModule` (or pulled
            in via the per-lab `registry.machines` listing).
          '';
        };

        userRegistries = mkOption {
          type = types.listOf userRegistryType;
          default = [ ];
          description = ''
            User registries to install on this machine. Each entry is
            typically a `flake.neusis.registry.users.<lab>` value.
            Threaded into the system builders, which use it both to
            create system accounts (via `mkDynamicUsers`) and to wire
            up home-manager (via the `hm-system-init` module).
          '';
        };
      };
    }
  );

  # Per-lab machine grouping by platform. Each entry is a
  # `flake.neusis.machines.<name>` value (or any inline value matching
  # `machineType`). The system builders consume these lists to produce
  # the actual `nixosConfigurations` / `darwinConfigurations`.
  machineRegistryType = types.submodule {
    options = {
      nixos = mkOption {
        type = types.listOf machineType;
        default = [ ];
        description = ''
          Machines in this lab built as NixOS hosts. Each entry is
          typically a reference like `self.neusis.machines.<name>`.
        '';
      };
      darwin = mkOption {
        type = types.listOf machineType;
        default = [ ];
        description = ''
          Machines in this lab built as nix-darwin hosts. Each entry is
          typically a reference like `self.neusis.machines.<name>`.
        '';
      };
    };
  };

  # Per-target feature module collections. Each sub-attr is a flat map
  # of named module fragments scoped to where they're consumable.
  featuresType = types.submodule {
    options = {
      nixos = mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = { };
        description = ''
          NixOS-only feature modules (e.g. `mesh`, networking
          features). Consumable from a NixOS host's module list.
        '';
      };
      darwin = mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = { };
        description = ''
          nix-darwin-only feature modules (e.g. `system-defaults`,
          `nix-homebrew`). Consumable from a Darwin host's module
          list.
        '';
      };
      agnostic = mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = { };
        description = ''
          Cross-platform feature modules (e.g. `nix-settings`,
          `nix-pkgs`). Safe to import from either a NixOS or Darwin
          host because they only touch options common to both.
        '';
      };
      hm = mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = { };
        description = ''
          home-manager feature modules. Consumable from a user's
          home-manager configuration.
        '';
      };
      flake = mkOption {
        type = types.lazyAttrsOf types.deferredModule;
        default = { };
        description = ''
          Flake-level feature modules. These are flake-parts modules
          themselves (not NixOS/HM modules), wiring inputs, dev shells,
          checks, or other flake-wide concerns (e.g. `agenix-rekey`).
        '';
      };
    };
  };

  # The top-level shape of `flake.neusis`.
  neusisType = types.submodule {
    options = {
      users = mkOption {
        type = types.lazyAttrsOf userType;
        default = { };
        description = ''
          Registry of users known to this flake. Attributes merge
          across files — one file can set
          `flake.neusis.users.ank.neusisOS.fullName` while another
          sets `flake.neusis.users.ank.neusisOS.sshKeys`.
        '';
      };

      registry = mkOption {
        default = { };
        description = ''
          Lab/site groupings of users and machines. Used as the input
          to system builders and as the merge point for cross-lab
          aggregations.
        '';
        type = types.submodule {
          options = {
            users = mkOption {
              type = types.lazyAttrsOf userRegistryType;
              default = { };
              description = ''
                Per-lab user groupings (admins/regulars/locked/guests).
                The conventional `all` key holds the merged result
                across every lab.
              '';
            };
            machines = mkOption {
              type = types.lazyAttrsOf machineRegistryType;
              default = { };
              description = ''
                Per-lab machine registries holding instantiated
                `nixosConfigurations` and `darwinConfigurations`.
              '';
            };
          };
        };
      };

      lib = mkOption {
        type = types.lazyAttrsOf types.raw;
        default = { };
        description = ''
          Flake-level library namespaces. Each top-level key (e.g.
          `neusisOS`, `utils`) is an independent namespace holding
          helper functions and builders. Values are `raw` — no merging
          across files, so each namespace must come from one file
          (typically using `rec` for internal references).
        '';
      };

      machines = mkOption {
        type = types.lazyAttrsOf machineType;
        default = { };
        description = ''
          Per-machine definitions, keyed by hostname. Each entry holds
          identity metadata (`hostname`, `computerName`, `hostPubkey`),
          the per-machine `modulesSpecialArgs`, and the root `module`
          that the system builders import as `userModule`.
        '';
      };

      features = mkOption {
        type = featuresType;
        default = { };
        description = ''
          Reusable feature module library. Organised by consumption
          target (`nixos`, `darwin`, `agnostic`, `hm`, `flake`); each
          inner attr is a deferred module fragment that machine or
          user configurations can pull in by name, e.g.
          `self.neusis.features.darwin.defaults`.
        '';
      };

    };
  };
in
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    neusis = mkOption {
      type = neusisType;
      default = { };
      description = ''
        Top-level neusis namespace. Holds the typed registry of users,
        per-lab groupings, and the neusisOS library.

        Consumers in flake-parts consumers see this once they import
        `inputs.neusis.flakeModules.default` (or `flakeModules.options`
        for just the schema without the lib implementation).
      '';
    };

    agnosticModules = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      description = ''
        System-agnostic neusis modules. Mirrors `flake.nixosModules`
        in shape, but the modules inside are expected to be portable
        across NixOS, nix-darwin, and home-manager — i.e. they only
        touch options that exist (or are shimmed) in every target.
      '';
    };

    # `homeModules` and `darwinModules` ARE standard community flake
    # outputs but the flake-parts version pinned here only declares
    # `nixosModules` as a typed option. We declare them ourselves so
    # nixd can complete `flake.homeModules.<TAB>` /
    # `flake.darwinModules.<TAB>` instead of treating them as
    # untyped freeform attributes.
    homeModules = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      description = ''
        Home-manager modules exposed by this flake — `imports` into
        a home-manager bundle via `self.homeModules.<name>`.
      '';
    };

    darwinModules = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      description = ''
        nix-darwin modules exposed by this flake — `imports` into
        a darwin host config via `self.darwinModules.<name>`.
      '';
    };
  };
}
